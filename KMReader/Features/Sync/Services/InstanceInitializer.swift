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
    let seriesSyncSucceeded = await syncSeriesIncremental(instanceId: instanceId, since: lastSyncedAt.series)
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
    let booksSyncSucceeded = await syncBooksIncremental(instanceId: instanceId, since: lastSyncedAt.books)
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

      while hasMore {
        let result: Page<SeriesCollection> = try await CollectionService.shared.getCollections(
          page: page, size: 100)
        await db.upsertCollections(result.content, instanceId: instanceId)
        await db.commit()

        totalPages = max(result.totalPages, 1)
        hasMore = !result.last
        page += 1

        updateProgress(phase: .collections, phaseProgress: Double(page) / Double(totalPages))
      }
      logger.info("📂 Synced collections")
      return true
    } catch {
      logger.error("❌ Failed to sync collections: \(error)")
      updateProgress(phase: .collections, phaseProgress: 1.0)
      return false
    }
  }

  private func syncSeriesIncremental(instanceId: String, since: Date) async -> Bool {
    updateProgress(phase: .series, phaseProgress: 0.0)
    do {
      var page = 0
      var shouldContinue = true
      var totalPages = 1

      while shouldContinue {
        let search = SeriesSearch(condition: nil)
        let result = try await SeriesService.shared.getSeriesList(
          search: search, page: page, size: 100, sort: "lastModified,desc")

        var itemsToSync: [Series] = []
        for series in result.content {
          if series.lastModified > since {
            itemsToSync.append(series)
          } else {
            // Reached items older than last sync, stop
            shouldContinue = false
            break
          }
        }

        if !itemsToSync.isEmpty {
          await db.upsertSeriesList(itemsToSync, instanceId: instanceId)
          await db.commit()
        }

        totalPages = max(result.totalPages, 1)

        // Stop if last page or found older items
        if result.last {
          shouldContinue = false
        }

        page += 1
        updateProgress(phase: .series, phaseProgress: Double(page) / Double(totalPages))
      }
      logger.info("📚 Synced series incrementally")
      return true
    } catch {
      logger.error("❌ Failed to sync series: \(error)")
      updateProgress(phase: .series, phaseProgress: 1.0)
      return false
    }
  }

  private func syncAllReadLists(instanceId: String) async -> Bool {
    updateProgress(phase: .readLists, phaseProgress: 0.0)
    do {
      var page = 0
      var hasMore = true
      var totalPages = 1

      while hasMore {
        let result: Page<ReadList> = try await ReadListService.shared.getReadLists(
          page: page, size: 100)
        await db.upsertReadLists(result.content, instanceId: instanceId)
        await db.commit()

        totalPages = max(result.totalPages, 1)
        hasMore = !result.last
        page += 1

        updateProgress(phase: .readLists, phaseProgress: Double(page) / Double(totalPages))
      }
      logger.info("📖 Synced read lists")
      return true
    } catch {
      logger.error("❌ Failed to sync read lists: \(error)")
      updateProgress(phase: .readLists, phaseProgress: 1.0)
      return false
    }
  }

  private func syncBooksIncremental(instanceId: String, since: Date) async -> Bool {
    updateProgress(phase: .books, phaseProgress: 0.0)
    do {
      var page = 0
      var shouldContinue = true
      var totalPages = 1

      while shouldContinue {
        let search = BookSearch(condition: nil)
        let result = try await BookService.shared.getBooksList(
          search: search, page: page, size: 100, sort: "lastModified,desc")

        var itemsToSync: [Book] = []
        for book in result.content {
          if book.lastModified > since {
            itemsToSync.append(book)
          } else {
            // Reached items older than last sync, stop
            shouldContinue = false
            break
          }
        }

        if !itemsToSync.isEmpty {
          await db.upsertBooks(itemsToSync, instanceId: instanceId)
          await db.commit()
        }

        totalPages = max(result.totalPages, 1)

        // Stop if last page or found older items
        if result.last {
          shouldContinue = false
        }

        page += 1
        updateProgress(phase: .books, phaseProgress: Double(page) / Double(totalPages))
      }
      logger.info("📖 Synced books incrementally")
      return true
    } catch {
      logger.error("❌ Failed to sync books: \(error)")
      updateProgress(phase: .books, phaseProgress: 1.0)
      return false
    }
  }

  // MARK: - Progress Helpers

  private func updateProgress(phase: SyncPhase, phaseProgress: Double) {
    let phaseOffset = phase.progressOffset
    let phaseContribution = (phase.weight / SyncPhase.totalWeight) * phaseProgress
    progress = phaseOffset + phaseContribution
  }
}
