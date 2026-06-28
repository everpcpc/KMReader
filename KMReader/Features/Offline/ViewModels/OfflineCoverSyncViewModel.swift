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
  @ObservationIgnored private var syncTask: Task<Void, Never>?

  private init() {}

  func startSyncMissingCovers(instanceId: String) {
    guard !isSyncing, !instanceId.isEmpty, !AppConfig.isOffline else { return }

    isSyncing = true
    activeInstanceId = instanceId
    progress = nil
    syncTask = Task { [weak self] in
      await self?.runSyncMissingCovers(instanceId: instanceId)
    }
  }

  func cancelSync() {
    syncTask?.cancel()
  }

  private func runSyncMissingCovers(instanceId: String) async {
    defer {
      isSyncing = false
      activeInstanceId = nil
      progress = nil
      syncTask = nil
    }

    do {
      let summary = try await OfflineCoverSyncService.shared.syncMissingCovers(
        instanceId: instanceId,
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
}
