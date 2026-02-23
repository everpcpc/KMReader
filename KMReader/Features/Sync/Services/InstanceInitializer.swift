//
// InstanceInitializer.swift
//
//

import Foundation
import OSLog
import SwiftUI

enum SyncPhase: String, CaseIterable {
  case libraries
  case collections
  case series
  case readLists
  case books

  var localizedName: String {
    switch self {
    case .libraries:
      String(localized: "initialization.phase.libraries")
    case .collections:
      String(localized: "initialization.phase.collections")
    case .series:
      String(localized: "initialization.phase.series")
    case .readLists:
      String(localized: "initialization.phase.readlists")
    case .books:
      String(localized: "initialization.phase.books")
    }
  }

  var weight: Double {
    switch self {
    case .libraries: 0.05
    case .collections: 0.1
    case .series: 0.25
    case .readLists: 0.1
    case .books: 0.5
    }
  }

  static var totalWeight: Double {
    allCases.reduce(0) { $0 + $1.weight }
  }

  var progressOffset: Double {
    var offset = 0.0
    for phase in SyncPhase.allCases {
      if phase == self { break }
      offset += phase.weight
    }
    return offset / SyncPhase.totalWeight
  }
}

@MainActor
@Observable
final class InstanceInitializer {
  static let shared = InstanceInitializer()

  private(set) var isSyncing = false
  private(set) var progress: Double = 0.0
  private(set) var currentPhase: SyncPhase = .libraries

  private let logger = AppLogger(.sync)
  private let api = APIClient.shared
  private let deletionReconcileInterval: TimeInterval = 24 * 60 * 60
  private let reconcileProgressSplit: Double = 0.7

  private init() {}

  var currentPhaseName: String {
    currentPhase.localizedName
  }

  private var db: DatabaseOperator {
    DatabaseOperator.shared
  }

  /// Sync data for the current instance.
  /// - Parameter forceFullSync: If true, ignores lastSyncedAt and fetches all series/books.
  func syncData(forceFullSync: Bool = false) async {
    guard !isSyncing else { return }
    let instanceId = AppConfig.current.instanceId
    guard !instanceId.isEmpty else { return }

    let hasFailures = await performSync(instanceId: instanceId, forceFullSync: forceFullSync)
    if hasFailures {
      ErrorManager.shared.notify(
        message: String(localized: "notification.offline.syncCompletedWithIssues")
      )
    } else {
      ErrorManager.shared.notify(
        message: String(localized: "notification.offline.syncCompleted")
      )
    }
  }

  func syncReadingProgressOnly() async {
    guard !isSyncing else { return }
    let instanceId = AppConfig.current.instanceId
    guard !instanceId.isEmpty else { return }
    await SyncService.shared.syncLatestRecentlyReadProgress()
  }

  private func performSync(instanceId: String, forceFullSync: Bool) async -> Bool {
    isSyncing = true
    progress = 0.0
    var hasFailures = false

    let storedLastSyncedAt = await db.getLastSyncedAt(instanceId: instanceId)
    let lastSyncedAt: (series: Date, books: Date) =
      forceFullSync
      ? (Date(timeIntervalSince1970: 0), Date(timeIntervalSince1970: 0))
      : storedLastSyncedAt
    let syncStartTime = Date()
    let shouldReconcileDeletions =
      forceFullSync || shouldRunDeletionReconciliation(instanceId: instanceId)

    logger.info(
      "🔄 Starting sync for instance: \(instanceId), forceFullSync: \(forceFullSync), seriesLastSynced: \(storedLastSyncedAt.series), booksLastSynced: \(storedLastSyncedAt.books)"
    )

    // Phase 1: Libraries (always full sync)
    currentPhase = .libraries
    if !(await syncLibraries(instanceId: instanceId)) {
      hasFailures = true
    }

    // Phase 2: Collections (always full sync)
    currentPhase = .collections
    if !(await syncAllCollections(instanceId: instanceId)) {
      hasFailures = true
    }

    // Phase 3: Series (incremental sync by lastModified)
    currentPhase = .series
    let seriesIncrementalEnd = shouldReconcileDeletions ? reconcileProgressSplit : 1.0
    var seriesSyncSucceeded = await syncSeriesIncremental(
      instanceId: instanceId,
      since: lastSyncedAt.series,
      progressRange: 0.0...seriesIncrementalEnd
    )
    if seriesSyncSucceeded && shouldReconcileDeletions {
      seriesSyncSucceeded = await reconcileSeriesDeletions(
        instanceId: instanceId,
        progressRange: seriesIncrementalEnd...1.0
      )
    }
    if !seriesSyncSucceeded {
      hasFailures = true
    } else {
      do {
        try await db.updateSeriesLastSyncedAt(
          instanceId: instanceId, date: syncStartTime)
        await db.commit()
      } catch {
        hasFailures = true
        logger.error("❌ Failed to update series lastSyncedAt: \(error)")
      }
    }

    // Phase 4: ReadLists (always full sync)
    currentPhase = .readLists
    if !(await syncAllReadLists(instanceId: instanceId)) {
      hasFailures = true
    }

    // Phase 5: Books (incremental sync by lastModified)
    currentPhase = .books
    let booksIncrementalEnd = shouldReconcileDeletions ? reconcileProgressSplit : 1.0
    var booksSyncSucceeded = await syncBooksIncremental(
      instanceId: instanceId,
      since: lastSyncedAt.books,
      progressRange: 0.0...booksIncrementalEnd
    )
    if booksSyncSucceeded && shouldReconcileDeletions {
      booksSyncSucceeded = await reconcileBookDeletions(
        instanceId: instanceId,
        progressRange: booksIncrementalEnd...1.0
      )
    }
    if !booksSyncSucceeded {
      hasFailures = true
    } else {
      do {
        try await db.updateBooksLastSyncedAt(
          instanceId: instanceId, date: syncStartTime)
        await db.commit()
      } catch {
        hasFailures = true
        logger.error("❌ Failed to update books lastSyncedAt: \(error)")
      }
    }

    // Keep reading progress aligned across all libraries (no dashboard library filter).
    await SyncService.shared.syncLatestRecentlyReadProgress()

    if shouldReconcileDeletions && seriesSyncSucceeded && booksSyncSucceeded {
      AppConfig.setDeletionReconcileTime(syncStartTime, instanceId: instanceId)
    }

    progress = 1.0
    if hasFailures {
      logger.warning("⚠️ Sync completed with errors for instance: \(instanceId)")
    } else {
      logger.info("✅ Sync completed for instance: \(instanceId)")
    }

    isSyncing = false
    return hasFailures
  }

  // MARK: - Sync Methods

  private func syncLibraries(instanceId: String) async -> Bool {
    updateProgress(phase: .libraries, phaseProgress: 0.0)
    do {
      let libraries = try await LibraryService.shared.getLibraries()
      let libraryInfos = libraries.map { LibraryInfo(id: $0.id, name: $0.name) }
      try await db.replaceLibraries(libraryInfos, for: instanceId)
      await db.commit()
      logger.info("📚 Synced \(libraries.count) libraries")
      updateProgress(phase: .libraries, phaseProgress: 1.0)
      return true
    } catch {
      logger.error("❌ Failed to sync libraries: \(error)")
      updateProgress(phase: .libraries, phaseProgress: 1.0)
      return false
    }
  }

  private func syncAllCollections(instanceId: String) async -> Bool {
    updateProgress(phase: .collections, phaseProgress: 0.0)
    do {
      var page = 0
      var hasMore = true
      var totalPages = 1
      var remoteCollectionIds = Set<String>()

      while hasMore {
        let result: Page<SeriesCollection> = try await CollectionService.shared.getCollections(
          page: page, size: 100)
        remoteCollectionIds.formUnion(result.content.map(\.id))
        await db.upsertCollections(result.content, instanceId: instanceId)
        await db.commit()

        totalPages = max(result.totalPages, 1)
        hasMore = !result.last
        page += 1

        updateProgress(phase: .collections, phaseProgress: Double(page) / Double(totalPages))
      }
      let deletedCount = await db.deleteCollectionsNotIn(remoteCollectionIds, instanceId: instanceId)
      if deletedCount > 0 {
        await db.commit()
        logger.info("🧹 Removed \(deletedCount) stale collections")
      }
      logger.info("📂 Synced collections")
      return true
    } catch {
      logger.error("❌ Failed to sync collections: \(error)")
      updateProgress(phase: .collections, phaseProgress: 1.0)
      return false
    }
  }

  private func syncSeriesIncremental(
    instanceId: String,
    since: Date,
    progressRange: ClosedRange<Double>
  ) async -> Bool {
    updateProgress(phase: .series, progressRange: progressRange, unitProgress: 0.0)
    do {
      var page = 0
      var shouldContinue = true

      while shouldContinue {
        let search = SeriesSearch(condition: nil)
        let result = try await SeriesService.shared.getSeriesList(
          search: search, page: page, size: 100, sort: "lastModified,desc")

        var itemsToSync: [Series] = []
        for series in result.content {
          if series.lastModified > since {
            itemsToSync.append(series)
          } else {
            shouldContinue = false
            break
          }
        }

        if !itemsToSync.isEmpty {
          await db.upsertSeriesList(itemsToSync, instanceId: instanceId)
          await db.commit()
        }

        page += 1

        if result.last {
          shouldContinue = false
        }

        let unitProgress =
          shouldContinue
          ? estimatedIncrementalProgress(processedPages: page)
          : 1.0
        updateProgress(phase: .series, progressRange: progressRange, unitProgress: unitProgress)
      }
      logger.info("📚 Synced series incrementally")
      return true
    } catch {
      logger.error("❌ Failed to sync series: \(error)")
      updateProgress(phase: .series, progressRange: progressRange, unitProgress: 1.0)
      return false
    }
  }

  private func reconcileSeriesDeletions(
    instanceId: String,
    progressRange: ClosedRange<Double>
  ) async -> Bool {
    updateProgress(phase: .series, progressRange: progressRange, unitProgress: 0.0)
    do {
      let remoteSeriesIds = try await fetchAllSeriesIdsForDeletionReconcile { progress in
        self.updateProgress(phase: .series, progressRange: progressRange, unitProgress: progress)
      }

      let deletedCount = await db.deleteSeriesNotIn(remoteSeriesIds, instanceId: instanceId)
      if deletedCount > 0 {
        await db.commit()
        logger.info("🧹 Removed \(deletedCount) stale series")
      }
      return true
    } catch {
      logger.error("❌ Failed to reconcile stale series: \(error)")
      return false
    }
  }

  private func syncAllReadLists(instanceId: String) async -> Bool {
    updateProgress(phase: .readLists, phaseProgress: 0.0)
    do {
      var page = 0
      var hasMore = true
      var totalPages = 1
      var remoteReadListIds = Set<String>()

      while hasMore {
        let result: Page<ReadList> = try await ReadListService.shared.getReadLists(
          page: page, size: 100)
        remoteReadListIds.formUnion(result.content.map(\.id))
        await db.upsertReadLists(result.content, instanceId: instanceId)
        await db.commit()

        totalPages = max(result.totalPages, 1)
        hasMore = !result.last
        page += 1

        updateProgress(phase: .readLists, phaseProgress: Double(page) / Double(totalPages))
      }
      let deletedCount = await db.deleteReadListsNotIn(remoteReadListIds, instanceId: instanceId)
      if deletedCount > 0 {
        await db.commit()
        logger.info("🧹 Removed \(deletedCount) stale read lists")
      }
      logger.info("📖 Synced read lists")
      return true
    } catch {
      logger.error("❌ Failed to sync read lists: \(error)")
      updateProgress(phase: .readLists, phaseProgress: 1.0)
      return false
    }
  }

  private func syncBooksIncremental(
    instanceId: String,
    since: Date,
    progressRange: ClosedRange<Double>
  ) async -> Bool {
    updateProgress(phase: .books, progressRange: progressRange, unitProgress: 0.0)
    do {
      var page = 0
      var shouldContinue = true

      while shouldContinue {
        let search = BookSearch(condition: nil)
        let result = try await BookService.shared.getBooksList(
          search: search, page: page, size: 100, sort: "lastModified,desc")

        var itemsToSync: [Book] = []
        for book in result.content {
          if book.lastModified > since {
            itemsToSync.append(book)
          } else {
            shouldContinue = false
            break
          }
        }

        if !itemsToSync.isEmpty {
          await db.upsertBooks(itemsToSync, instanceId: instanceId)
          await db.commit()
        }

        page += 1

        if result.last {
          shouldContinue = false
        }

        let unitProgress =
          shouldContinue
          ? estimatedIncrementalProgress(processedPages: page)
          : 1.0
        updateProgress(phase: .books, progressRange: progressRange, unitProgress: unitProgress)
      }
      logger.info("📖 Synced books incrementally")
      return true
    } catch {
      logger.error("❌ Failed to sync books: \(error)")
      updateProgress(phase: .books, progressRange: progressRange, unitProgress: 1.0)
      return false
    }
  }

  private func reconcileBookDeletions(
    instanceId: String,
    progressRange: ClosedRange<Double>
  ) async -> Bool {
    updateProgress(phase: .books, progressRange: progressRange, unitProgress: 0.0)
    do {
      let remoteBookIds = try await fetchAllBookIdsForDeletionReconcile { progress in
        self.updateProgress(phase: .books, progressRange: progressRange, unitProgress: progress)
      }

      let deletedCount = await db.deleteBooksNotIn(remoteBookIds, instanceId: instanceId)
      if deletedCount > 0 {
        await db.commit()
        let cleanupResult = await OfflineManager.shared.cleanupOrphanedFiles()
        if cleanupResult.deletedCount > 0 {
          logger.info(
            "🧹 Cleaned \(cleanupResult.deletedCount) orphaned offline directories after stale book removal")
        }
        logger.info("🧹 Removed \(deletedCount) stale books")
      }
      return true
    } catch {
      logger.error("❌ Failed to reconcile stale books: \(error)")
      return false
    }
  }

  private func fetchAllSeriesIdsForDeletionReconcile(
    onProgress: @escaping @MainActor (Double) -> Void
  ) async throws -> Set<String> {
    let search = SeriesSearch(condition: nil)

    do {
      let result = try await SeriesService.shared.getSeriesList(
        search: search,
        sort: "lastModified,desc",
        unpaged: true
      )
      onProgress(1.0)
      return Set(result.content.map(\.id))
    } catch {
      logger.warning("⚠️ Unpaged series reconcile failed, fallback to paged scan: \(error)")
    }

    var page = 0
    var hasMore = true
    var ids = Set<String>()
    while hasMore {
      let result = try await SeriesService.shared.getSeriesList(
        search: search,
        page: page,
        size: 500,
        sort: "lastModified,desc"
      )
      ids.formUnion(result.content.map(\.id))
      hasMore = !result.last
      page += 1
      let totalPages = max(result.totalPages, 1)
      onProgress(min(Double(page) / Double(totalPages), 1.0))
    }
    return ids
  }

  private func fetchAllBookIdsForDeletionReconcile(
    onProgress: @escaping @MainActor (Double) -> Void
  ) async throws -> Set<String> {
    let search = BookSearch(condition: nil)

    do {
      let result = try await BookService.shared.getBooksList(
        search: search,
        sort: "lastModified,desc",
        unpaged: true
      )
      onProgress(1.0)
      return Set(result.content.map(\.id))
    } catch {
      logger.warning("⚠️ Unpaged book reconcile failed, fallback to paged scan: \(error)")
    }

    var page = 0
    var hasMore = true
    var ids = Set<String>()
    while hasMore {
      let result = try await BookService.shared.getBooksList(
        search: search,
        page: page,
        size: 500,
        sort: "lastModified,desc"
      )
      ids.formUnion(result.content.map(\.id))
      hasMore = !result.last
      page += 1
      let totalPages = max(result.totalPages, 1)
      onProgress(min(Double(page) / Double(totalPages), 1.0))
    }
    return ids
  }

  // MARK: - Progress Helpers

  private func shouldRunDeletionReconciliation(instanceId: String) -> Bool {
    guard let lastRun = AppConfig.deletionReconcileTime(instanceId: instanceId) else {
      return true
    }
    return Date().timeIntervalSince(lastRun) >= deletionReconcileInterval
  }

  private func estimatedIncrementalProgress(processedPages: Int) -> Double {
    guard processedPages > 0 else { return 0.0 }
    return min(Double(processedPages) / Double(processedPages + 2), 0.9)
  }

  private func updateProgress(
    phase: SyncPhase,
    progressRange: ClosedRange<Double>,
    unitProgress: Double
  ) {
    let clampedUnit = min(max(unitProgress, 0.0), 1.0)
    let mapped =
      progressRange.lowerBound
      + (progressRange.upperBound - progressRange.lowerBound) * clampedUnit
    updateProgress(phase: phase, phaseProgress: mapped)
  }

  private func updateProgress(phase: SyncPhase, phaseProgress: Double) {
    let phaseOffset = phase.progressOffset
    let phaseContribution = (phase.weight / SyncPhase.totalWeight) * phaseProgress
    progress = phaseOffset + phaseContribution
  }
}
