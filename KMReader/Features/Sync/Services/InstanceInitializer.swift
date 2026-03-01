//
// InstanceInitializer.swift
//
//

import Foundation
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

  static var initialProgress: [SyncPhase: Double] {
    Dictionary(uniqueKeysWithValues: allCases.map { ($0, 0.0) })
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

enum SyncStage: String, CaseIterable {
  case libraries
  case collections
  case seriesIncremental
  case seriesReconcile
  case readLists
  case booksIncremental
  case booksReconcile

  static func visibleStages(includeReconcile: Bool) -> [SyncStage] {
    if includeReconcile {
      [
        .libraries,
        .collections,
        .seriesIncremental,
        .seriesReconcile,
        .readLists,
        .booksIncremental,
        .booksReconcile,
      ]
    } else {
      [
        .libraries,
        .collections,
        .seriesIncremental,
        .readLists,
        .booksIncremental,
      ]
    }
  }

  static var initialProgress: [SyncStage: Double] {
    Dictionary(uniqueKeysWithValues: allCases.map { ($0, 0.0) })
  }

  func localizedName(includeReconcile: Bool) -> String {
    switch self {
    case .libraries:
      return String(localized: "initialization.phase.libraries")
    case .collections:
      return String(localized: "initialization.phase.collections")
    case .seriesIncremental:
      let base = String(localized: "initialization.phase.series")
      return includeReconcile ? "\(base) (1/2)" : base
    case .seriesReconcile:
      let base = String(localized: "initialization.phase.series")
      return "\(base) (2/2)"
    case .readLists:
      return String(localized: "initialization.phase.readlists")
    case .booksIncremental:
      let base = String(localized: "initialization.phase.books")
      return includeReconcile ? "\(base) (1/2)" : base
    case .booksReconcile:
      let base = String(localized: "initialization.phase.books")
      return "\(base) (2/2)"
    }
  }
}

@MainActor
@Observable
final class InstanceInitializer {
  static let shared = InstanceInitializer()

  private(set) var isSyncing = false
  private(set) var progress: Double = 0.0
  private(set) var currentPhase: SyncPhase = .libraries
  private(set) var phaseProgress: [SyncPhase: Double] = SyncPhase.initialProgress
  private(set) var stageProgress: [SyncStage: Double] = SyncStage.initialProgress
  private(set) var visibleStages: [SyncStage] = SyncStage.visibleStages(includeReconcile: false)
  private(set) var includesReconcileStages = false

  private let logger = AppLogger(.sync)
  private let syncPageSize = 1000

  private init() {}

  var currentPhaseName: String {
    currentPhase.localizedName
  }

  func progress(for phase: SyncPhase) -> Double {
    phaseProgress[phase] ?? 0.0
  }

  func progress(for stage: SyncStage) -> Double {
    stageProgress[stage] ?? 0.0
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

  func syncReadingProgressOnly(force: Bool = false) async {
    guard !isSyncing else { return }
    let instanceId = AppConfig.current.instanceId
    guard !instanceId.isEmpty else { return }

    if !force, shouldSkipReadingProgressSync(instanceId: instanceId) {
      return
    }

    let syncSucceeded = await SyncService.shared.syncLatestRecentlyReadProgress()
    guard syncSucceeded else { return }

    AppConfig.setReadingProgressSyncTime(Date(), instanceId: instanceId)
    ErrorManager.shared.notify(
      message: String(
        localized: "notification.offline.readHistorySyncCompleted",
        defaultValue: "Reading history sync completed"
      )
    )
  }

  private func performSync(instanceId: String, forceFullSync: Bool) async -> Bool {
    isSyncing = true
    progress = 0.0
    phaseProgress = SyncPhase.initialProgress
    stageProgress = SyncStage.initialProgress
    var hasFailures = false

    let storedLastSyncedAt = await db.getLastSyncedAt(instanceId: instanceId)
    let lastSyncedAt: (series: Date, books: Date) =
      forceFullSync
      ? (Date(timeIntervalSince1970: 0), Date(timeIntervalSince1970: 0))
      : storedLastSyncedAt
    let syncStartTime = Date()
    let shouldReconcileDeletions = forceFullSync
    includesReconcileStages = shouldReconcileDeletions
    visibleStages = SyncStage.visibleStages(includeReconcile: shouldReconcileDeletions)

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
    var seriesSyncSucceeded = await syncSeriesIncremental(
      instanceId: instanceId,
      since: lastSyncedAt.series
    )
    if seriesSyncSucceeded && shouldReconcileDeletions {
      seriesSyncSucceeded = await reconcileSeriesDeletions(
        instanceId: instanceId
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
    var booksSyncSucceeded = await syncBooksIncremental(
      instanceId: instanceId,
      since: lastSyncedAt.books
    )
    if booksSyncSucceeded && shouldReconcileDeletions {
      booksSyncSucceeded = await reconcileBookDeletions(
        instanceId: instanceId
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
    let readProgressSyncSucceeded = await SyncService.shared.syncLatestRecentlyReadProgress()
    if readProgressSyncSucceeded {
      AppConfig.setReadingProgressSyncTime(Date(), instanceId: instanceId)
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

  private func shouldSkipReadingProgressSync(instanceId: String) -> Bool {
    let interval: TimeInterval = 24 * 60 * 60
    guard let lastSyncTime = AppConfig.readingProgressSyncTime(instanceId: instanceId) else {
      return false
    }
    return Date().timeIntervalSince(lastSyncTime) < interval
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
          page: page, size: syncPageSize)
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
    since: Date
  ) async -> Bool {
    updateProgress(phase: .series, phaseProgress: 0.0, stage: .seriesIncremental)
    do {
      var page = 0
      var shouldContinue = true

      while shouldContinue {
        let search = SeriesSearch(condition: nil)
        let result = try await SeriesService.shared.getSeriesList(
          search: search, page: page, size: syncPageSize, sort: "lastModified,desc")

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
        updateProgress(phase: .series, phaseProgress: unitProgress, stage: .seriesIncremental)
      }
      logger.info("📚 Synced series incrementally")
      return true
    } catch {
      logger.error("❌ Failed to sync series: \(error)")
      updateProgress(phase: .series, phaseProgress: 1.0, stage: .seriesIncremental)
      return false
    }
  }

  private func reconcileSeriesDeletions(instanceId: String) async -> Bool {
    updateProgress(phase: .series, phaseProgress: 0.0, stage: .seriesReconcile)
    do {
      let localCount = await db.fetchTotalSeriesCount(instanceId: instanceId)
      do {
        let remoteCount = try await fetchRemoteSeriesCountForDeletionReconcile()
        if localCount <= remoteCount {
          logger.debug(
            "⏭️ Skipped series reconcile: localCount=\(localCount), remoteCount=\(remoteCount)"
          )
          updateProgress(phase: .series, phaseProgress: 1.0, stage: .seriesReconcile)
          return true
        }
      } catch {
        logger.warning(
          "⚠️ Failed to preflight series reconcile counts, fallback to full scan: \(error)"
        )
      }

      let remoteSeriesIds = try await fetchAllSeriesIdsForDeletionReconcile { progress in
        self.updateProgress(phase: .series, phaseProgress: progress, stage: .seriesReconcile)
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
          page: page, size: syncPageSize)
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
    since: Date
  ) async -> Bool {
    updateProgress(phase: .books, phaseProgress: 0.0, stage: .booksIncremental)
    do {
      var page = 0
      var shouldContinue = true

      while shouldContinue {
        let search = BookSearch(condition: nil)
        let result = try await BookService.shared.getBooksList(
          search: search, page: page, size: syncPageSize, sort: "lastModified,desc")

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
        updateProgress(phase: .books, phaseProgress: unitProgress, stage: .booksIncremental)
      }
      logger.info("📖 Synced books incrementally")
      return true
    } catch {
      logger.error("❌ Failed to sync books: \(error)")
      updateProgress(phase: .books, phaseProgress: 1.0, stage: .booksIncremental)
      return false
    }
  }

  private func reconcileBookDeletions(instanceId: String) async -> Bool {
    updateProgress(phase: .books, phaseProgress: 0.0, stage: .booksReconcile)
    do {
      let localCount = await db.fetchTotalBooksCount(instanceId: instanceId)
      do {
        let remoteCount = try await fetchRemoteBookCountForDeletionReconcile()
        if localCount <= remoteCount {
          logger.debug(
            "⏭️ Skipped book reconcile: localCount=\(localCount), remoteCount=\(remoteCount)"
          )
          updateProgress(phase: .books, phaseProgress: 1.0, stage: .booksReconcile)
          return true
        }
      } catch {
        logger.warning(
          "⚠️ Failed to preflight book reconcile counts, fallback to full scan: \(error)"
        )
      }

      let remoteBookIds = try await fetchAllBookIdsForDeletionReconcile { progress in
        self.updateProgress(phase: .books, phaseProgress: progress, stage: .booksReconcile)
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

  private func fetchRemoteSeriesCountForDeletionReconcile() async throws -> Int {
    let result = try await SeriesService.shared.getSeriesList(
      search: SeriesSearch(condition: nil),
      page: 0,
      size: 1,
      sort: "lastModified,desc"
    )
    return result.totalElements
  }

  private func fetchRemoteBookCountForDeletionReconcile() async throws -> Int {
    let result = try await BookService.shared.getBooksList(
      search: BookSearch(condition: nil),
      page: 0,
      size: 1,
      sort: "lastModified,desc"
    )
    return result.totalElements
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
        size: syncPageSize,
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
        size: syncPageSize,
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

  private func estimatedIncrementalProgress(processedPages: Int) -> Double {
    guard processedPages > 0 else { return 0.0 }
    return min(Double(processedPages) / Double(processedPages + 2), 0.9)
  }

  private func updateProgress(
    phase: SyncPhase,
    phaseProgress: Double,
    stage: SyncStage? = nil
  ) {
    let clampedPhaseProgress = min(max(phaseProgress, 0.0), 1.0)
    let effectivePhaseProgress = updateStageProgress(
      phase: phase,
      phaseProgress: clampedPhaseProgress,
      stage: stage
    )
    self.phaseProgress[phase] = effectivePhaseProgress
    let phaseOffset = phase.progressOffset
    let phaseContribution = (phase.weight / SyncPhase.totalWeight) * effectivePhaseProgress
    progress = phaseOffset + phaseContribution
  }

  private func updateStageProgress(
    phase: SyncPhase,
    phaseProgress: Double,
    stage: SyncStage?
  ) -> Double {
    switch phase {
    case .libraries:
      stageProgress[.libraries] = phaseProgress
      return phaseProgress
    case .collections:
      stageProgress[.collections] = phaseProgress
      return phaseProgress
    case .readLists:
      stageProgress[.readLists] = phaseProgress
      return phaseProgress
    case .series:
      return updateSplitStageProgress(
        incrementalStage: .seriesIncremental,
        reconcileStage: .seriesReconcile,
        phaseProgress: phaseProgress,
        stage: stage
      )
    case .books:
      return updateSplitStageProgress(
        incrementalStage: .booksIncremental,
        reconcileStage: .booksReconcile,
        phaseProgress: phaseProgress,
        stage: stage
      )
    }
  }

  private func updateSplitStageProgress(
    incrementalStage: SyncStage,
    reconcileStage: SyncStage,
    phaseProgress: Double,
    stage: SyncStage?
  ) -> Double {
    guard includesReconcileStages else {
      stageProgress[incrementalStage] = phaseProgress
      stageProgress[reconcileStage] = 0.0
      return phaseProgress
    }

    if stage == incrementalStage {
      stageProgress[incrementalStage] = phaseProgress
    } else if stage == reconcileStage {
      stageProgress[reconcileStage] = phaseProgress
    }

    let incrementalProgress = stageProgress[incrementalStage] ?? 0.0
    let reconcileProgress = stageProgress[reconcileStage] ?? 0.0
    return (incrementalProgress + reconcileProgress) / 2.0
  }
}
