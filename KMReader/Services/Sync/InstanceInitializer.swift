//
//  InstanceInitializer.swift
//  KMReader
//
//  Created by Komga iOS Client
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

  /// Sync data for the current instance. Uses incremental sync based on lastModified.
  func syncData() async {
    let instanceId = AppConfig.currentInstanceId
    guard !instanceId.isEmpty else { return }

    await performSync(instanceId: instanceId)
  }

  private func performSync(instanceId: String) async {
    isSyncing = true
    progress = 0.0

    let lastSyncedAt = KomgaInstanceStore.shared.getLastSyncedAt(instanceId: instanceId)
    let syncStartTime = Date()

    logger.info(
      "🔄 Starting sync for instance: \(instanceId), seriesLastSynced: \(lastSyncedAt.series), booksLastSynced: \(lastSyncedAt.books)"
    )

    // Phase 1: Libraries (always full sync)
    currentPhase = .libraries
    await syncLibraries(instanceId: instanceId)

    // Phase 2: Collections (always full sync)
    currentPhase = .collections
    await syncAllCollections(instanceId: instanceId)

    // Phase 3: Series (incremental sync by lastModified)
    currentPhase = .series
    await syncSeriesIncremental(instanceId: instanceId, since: lastSyncedAt.series)
    do {
      try KomgaInstanceStore.shared.updateSeriesLastSyncedAt(
        instanceId: instanceId, date: syncStartTime)
    } catch {
      logger.error("❌ Failed to update series lastSyncedAt: \(error)")
    }

    // Phase 4: ReadLists (always full sync)
    currentPhase = .readLists
    await syncAllReadLists(instanceId: instanceId)

    // Phase 5: Books (incremental sync by lastModified)
    currentPhase = .books
    await syncBooksIncremental(instanceId: instanceId, since: lastSyncedAt.books)
    do {
      try KomgaInstanceStore.shared.updateBooksLastSyncedAt(
        instanceId: instanceId, date: syncStartTime)
    } catch {
      logger.error("❌ Failed to update books lastSyncedAt: \(error)")
    }

    progress = 1.0
    logger.info("✅ Sync completed for instance: \(instanceId)")

    isSyncing = false
  }

  // MARK: - Sync Methods

  private func syncLibraries(instanceId: String) async {
    updateProgress(phase: .libraries, phaseProgress: 0.0)
    do {
      let libraries: [Library] = try await api.request(path: "/api/v1/libraries")
      let libraryInfos = libraries.map { LibraryInfo(id: $0.id, name: $0.name) }
      try KomgaLibraryStore.shared.replaceLibraries(libraryInfos, for: instanceId)
      logger.info("📚 Synced \(libraries.count) libraries")
    } catch {
      logger.error("❌ Failed to sync libraries: \(error)")
    }
    updateProgress(phase: .libraries, phaseProgress: 1.0)
  }

  private func syncAllCollections(instanceId: String) async {
    updateProgress(phase: .collections, phaseProgress: 0.0)
    do {
      var page = 0
      var hasMore = true
      var totalPages = 1

      while hasMore {
        let result: Page<SeriesCollection> = try await CollectionService.shared.getCollections(
          page: page, size: 100)
        await db.upsertCollections(result.content, instanceId: instanceId)
        try await db.commit()

        totalPages = max(result.totalPages, 1)
        hasMore = !result.last
        page += 1

        updateProgress(phase: .collections, phaseProgress: Double(page) / Double(totalPages))
      }
      logger.info("📂 Synced collections")
    } catch {
      logger.error("❌ Failed to sync collections: \(error)")
    }
  }

  private func syncSeriesIncremental(instanceId: String, since: Date) async {
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
          try await db.commit()
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
    } catch {
      logger.error("❌ Failed to sync series: \(error)")
    }
  }

  private func syncAllReadLists(instanceId: String) async {
    updateProgress(phase: .readLists, phaseProgress: 0.0)
    do {
      var page = 0
      var hasMore = true
      var totalPages = 1

      while hasMore {
        let result: Page<ReadList> = try await ReadListService.shared.getReadLists(
          page: page, size: 100)
        await db.upsertReadLists(result.content, instanceId: instanceId)
        try await db.commit()

        totalPages = max(result.totalPages, 1)
        hasMore = !result.last
        page += 1

        updateProgress(phase: .readLists, phaseProgress: Double(page) / Double(totalPages))
      }
      logger.info("📖 Synced read lists")
    } catch {
      logger.error("❌ Failed to sync read lists: \(error)")
    }
  }

  private func syncBooksIncremental(instanceId: String, since: Date) async {
    updateProgress(phase: .books, phaseProgress: 0.0)
    do {
      var page = 0
      var shouldContinue = true
      var totalPages = 1

      while shouldContinue {
        let search = BookSearch(condition: nil)
        let result = try await BookService.shared.getBooksList(
          search: search, page: page, size: 500, sort: "lastModified,desc")

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
          try await db.commit()
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
    } catch {
      logger.error("❌ Failed to sync books: \(error)")
    }
  }

  // MARK: - Progress Helpers

  private func updateProgress(phase: SyncPhase, phaseProgress: Double) {
    let phaseOffset = phase.progressOffset
    let phaseContribution = (phase.weight / SyncPhase.totalWeight) * phaseProgress
    progress = phaseOffset + phaseContribution
  }
}
