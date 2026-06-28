//
// OfflineCoverSyncViewModel.swift
//
//

import Foundation

@MainActor
@Observable
final class OfflineCoverSyncViewModel {
  static let shared = OfflineCoverSyncViewModel()

  private(set) var isSyncing = false
  private(set) var activeInstanceId: String?
  private(set) var progress: OfflineCoverSyncProgress?
  private(set) var libraries: [LibraryInfo] = []
  private(set) var selectedLibraryIds: Set<String> = []
  @ObservationIgnored private var syncTask: Task<Void, Never>?
  @ObservationIgnored private var libraryScopeInstanceId: String?

  private init() {}

  var syncsAllLibraries: Bool {
    selectedLibraryIds.isEmpty
  }

  func loadLibraryScopeOptions(instanceId: String) async {
    guard !instanceId.isEmpty else {
      clearLibraryScope()
      return
    }

    guard let database = try? await DatabaseOperator.database() else {
      clearLibraryScope()
      return
    }

    let loadedLibraries = await database.fetchLibraries(instanceId: instanceId)
      .filter { $0.id != KomgaLibrary.allLibrariesId }

    if libraryScopeInstanceId != instanceId {
      libraryScopeInstanceId = instanceId
      selectedLibraryIds = []
    }

    if libraries != loadedLibraries {
      libraries = loadedLibraries
    }

    normalizeSelectedLibraryIds()
  }

  func selectedLibraryIdsForSync(instanceId: String) -> [String] {
    guard libraryScopeInstanceId == instanceId else { return [] }
    return selectedLibraryIds.sorted()
  }

  func selectLibraries(_ libraryIds: Set<String>) {
    selectedLibraryIds = libraryIds
    normalizeSelectedLibraryIds()
  }

  func startSyncMissingCovers(instanceId: String, libraryIds: [String]) {
    guard !isSyncing, !instanceId.isEmpty, !AppConfig.isOffline else { return }

    isSyncing = true
    activeInstanceId = instanceId
    progress = nil
    syncTask = Task { [weak self] in
      await self?.runSyncMissingCovers(instanceId: instanceId, libraryIds: libraryIds)
    }
  }

  func cancelSync() {
    syncTask?.cancel()
  }

  func cancelSyncIfContextChanged(instanceId: String, isOffline: Bool) {
    guard isSyncing else { return }
    if isOffline || activeInstanceId != instanceId {
      cancelSync()
    }
  }

  private func runSyncMissingCovers(instanceId: String, libraryIds: [String]) async {
    defer {
      isSyncing = false
      activeInstanceId = nil
      progress = nil
      syncTask = nil
    }

    do {
      let summary = try await OfflineCoverSyncService.shared.syncMissingCovers(
        instanceId: instanceId,
        libraryIds: libraryIds,
        onProgress: { [weak self] progress in
          guard self?.activeInstanceId == instanceId else { return }
          self?.progress = progress
        }
      )
      notifyCoverSyncResult(summary)
    } catch is CancellationError {
      notifyCoverSyncCancelled()
    } catch {
      ErrorManager.shared.alert(error: error)
    }
  }

  private func notifyCoverSyncResult(_ summary: OfflineCoverSyncSummary) {
    if summary.wasCancelled {
      notifyCoverSyncCancelled()
    } else if summary.stoppedAtCacheLimit {
      ErrorManager.shared.notify(
        message: String(localized: "notification.offline.coverSync.maxSizeReached"),
        duration: 3
      )
    } else if summary.storedCount > 0 && summary.failedCount > 0 {
      ErrorManager.shared.notify(
        message: String(
          localized:
            "notification.offline.coverSync.partial \(summary.storedCount) \(summary.failedCount)"
        ),
        duration: 3
      )
    } else if summary.storedCount > 0 {
      ErrorManager.shared.notify(
        message: String(
          localized: "notification.offline.coverSync.synced \(summary.storedCount)"
        ),
        duration: 3
      )
    } else if summary.failedCount > 0 {
      ErrorManager.shared.notify(
        message: String(
          localized: "notification.offline.coverSync.failed \(summary.failedCount)"
        ),
        duration: 3
      )
    } else {
      ErrorManager.shared.notify(
        message: String(localized: "notification.offline.coverSync.upToDate")
      )
    }
  }

  private func notifyCoverSyncCancelled() {
    ErrorManager.shared.notify(
      message: String(localized: "notification.offline.coverSync.cancelled"),
      duration: 3
    )
  }

  private func clearLibraryScope() {
    libraryScopeInstanceId = nil
    libraries = []
    selectedLibraryIds = []
  }

  private func normalizeSelectedLibraryIds() {
    guard !libraries.isEmpty else {
      selectedLibraryIds = []
      return
    }

    let validLibraryIds = Set(libraries.map(\.id))
    selectedLibraryIds = selectedLibraryIds.intersection(validLibraryIds)
    if selectedLibraryIds.count == validLibraryIds.count {
      selectedLibraryIds = []
    }
  }
}
