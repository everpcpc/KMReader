//
// SyncWorker.swift
//
//

import Foundation

actor SyncWorker {
  private let logger = AppLogger(.sync)
  private let syncPageSize = 1000
  private let recentlyReadSyncPageSize = 200

  func sync(
    request: SyncRequest,
    onProgress: @escaping SyncProgressHandler
  ) async -> SyncResult {
    var hasFailures = false

    do {
      let database = try await DatabaseOperator.database()
      let storedLastSyncedAt = await database.getLastSyncedAt(instanceId: request.instanceId)
      let lastSyncedAt: (series: Date, books: Date) =
        request.forceFullSync
        ? (Date(timeIntervalSince1970: 0), Date(timeIntervalSince1970: 0))
        : storedLastSyncedAt
      let syncStartTime = Date()

      logger.info(
        "🔄 Starting sync for instance: \(request.instanceId), forceFullSync: \(request.forceFullSync), seriesLastSynced: \(storedLastSyncedAt.series), booksLastSynced: \(storedLastSyncedAt.books)"
      )

      if !(await syncLibraries(
        instanceId: request.instanceId,
        database: database,
        onProgress: onProgress
      )) {
        hasFailures = true
      }

      if !(await syncAllCollections(
        instanceId: request.instanceId,
        database: database,
        onProgress: onProgress
      )) {
        hasFailures = true
      }

      var seriesSyncSucceeded = await syncSeriesIncremental(
        instanceId: request.instanceId,
        since: lastSyncedAt.series,
        database: database,
        onProgress: onProgress
      )
      if seriesSyncSucceeded && request.forceFullSync {
        seriesSyncSucceeded = await reconcileSeriesDeletions(
          instanceId: request.instanceId,
          database: database,
          onProgress: onProgress
        )
      }
      if !seriesSyncSucceeded {
        hasFailures = true
      } else {
        do {
          try await database.updateSeriesLastSyncedAt(
            instanceId: request.instanceId,
            date: syncStartTime
          )
          await database.commit()
        } catch {
          hasFailures = true
          logger.error("❌ Failed to update series lastSyncedAt: \(error)")
        }
      }

      if !(await syncAllReadLists(
        instanceId: request.instanceId,
        database: database,
        onProgress: onProgress
      )) {
        hasFailures = true
      }

      var booksSyncSucceeded = await syncBooksIncremental(
        instanceId: request.instanceId,
        since: lastSyncedAt.books,
        database: database,
        onProgress: onProgress
      )
      if booksSyncSucceeded && request.forceFullSync {
        booksSyncSucceeded = await reconcileBookDeletions(
          instanceId: request.instanceId,
          database: database,
          onProgress: onProgress
        )
      }
      if !booksSyncSucceeded {
        hasFailures = true
      } else {
        do {
          try await database.updateBooksLastSyncedAt(
            instanceId: request.instanceId,
            date: syncStartTime
          )
          await database.commit()
        } catch {
          hasFailures = true
          logger.error("❌ Failed to update books lastSyncedAt: \(error)")
        }
      }

      let readingProgressSynced = await syncReadingProgress(instanceId: request.instanceId)

      if hasFailures {
        logger.warning("⚠️ Sync completed with errors for instance: \(request.instanceId)")
      } else {
        logger.info("✅ Sync completed for instance: \(request.instanceId)")
      }

      return SyncResult(
        hasFailures: hasFailures,
        readingProgressSynced: readingProgressSynced
      )
    } catch {
      logger.error("❌ Failed to load sync markers: \(error)")
      return SyncResult(hasFailures: true, readingProgressSynced: false)
    }
  }

  func syncReadingProgress(instanceId: String) async -> Bool {
    guard !instanceId.isEmpty else { return false }
    guard let database = await DatabaseOperator.databaseIfConfigured() else {
      logger.error("❌ Failed to get database operator for reading progress sync")
      return false
    }

    let marker = AppConfig.recentlyReadRecordTime(instanceId: instanceId)
    var page = 0
    var shouldContinue = true
    var latestServerReadDate = marker
    var syncedCount = 0

    do {
      while shouldContinue {
        let result = try await BookService.getBooksList(
          search: BookSearch(condition: nil),
          page: page,
          size: recentlyReadSyncPageSize,
          sort: "readProgress.readDate,desc"
        )

        let books = result.content
        guard !books.isEmpty else { break }

        if let newestInPage = books.compactMap({ $0.readProgress?.readDate }).max() {
          if let currentLatest = latestServerReadDate {
            latestServerReadDate = max(currentLatest, newestInPage)
          } else {
            latestServerReadDate = newestInPage
          }
        }

        let booksToSync: [Book]
        if let marker {
          booksToSync = books.filter { book in
            guard let readDate = book.readProgress?.readDate else { return false }
            return readDate > marker
          }
          let reachedMarker = books.contains { book in
            guard let readDate = book.readProgress?.readDate else { return true }
            return readDate <= marker
          }
          shouldContinue = !result.last && !reachedMarker
        } else {
          booksToSync = books.filter { $0.readProgress?.readDate != nil }
          shouldContinue = false
        }

        if !booksToSync.isEmpty {
          await database.upsertReadingProgressBooks(
            booksToSync,
            instanceId: instanceId
          )
          syncedCount += booksToSync.count
        }

        page += 1
      }

      if await database.hasChanges() {
        try await database.commitImmediately()
      }

      if let latestServerReadDate {
        AppConfig.setRecentlyReadRecordTime(latestServerReadDate, instanceId: instanceId)
      }

      logger.debug(
        "📘 Synced latest recently-read progress: count=\(syncedCount), marker=\(String(describing: latestServerReadDate))"
      )
      return true
    } catch {
      logger.warning("⚠️ Failed to sync latest recently-read progress: \(error)")
      return false
    }
  }

  private func syncLibraries(
    instanceId: String,
    database: DatabaseOperator,
    onProgress: SyncProgressHandler
  ) async -> Bool {
    await report(.libraries, progress: 0.0, onProgress: onProgress)
    do {
      let libraries = try await LibraryService.getLibraries()
      let libraryInfos = libraries.map { LibraryInfo(id: $0.id, name: $0.name) }
      try await database.replaceLibraries(libraryInfos, for: instanceId)
      await database.commit()
      logger.info("📚 Synced \(libraries.count) libraries")
      await report(.libraries, progress: 1.0, onProgress: onProgress)
      return true
    } catch {
      logger.error("❌ Failed to sync libraries: \(error)")
      await report(.libraries, progress: 1.0, onProgress: onProgress)
      return false
    }
  }

  private func syncAllCollections(
    instanceId: String,
    database: DatabaseOperator,
    onProgress: SyncProgressHandler
  ) async -> Bool {
    await report(.collections, progress: 0.0, onProgress: onProgress)
    do {
      var page = 0
      var hasMore = true
      var totalPages = 1
      var remoteCollectionIds = Set<String>()

      while hasMore {
        let result: Page<SeriesCollection> = try await CollectionService.getCollections(
          page: page,
          size: syncPageSize
        )
        remoteCollectionIds.formUnion(result.content.map(\.id))
        await database.upsertCollections(result.content, instanceId: instanceId)
        await database.commit()

        totalPages = max(result.totalPages, 1)
        hasMore = !result.last
        page += 1

        await report(
          .collections,
          progress: Double(page) / Double(totalPages),
          onProgress: onProgress
        )
      }

      let deletedCount = await database.deleteCollectionsNotIn(
        remoteCollectionIds,
        instanceId: instanceId
      )
      if deletedCount > 0 {
        await database.commit()
        logger.info("🧹 Removed \(deletedCount) stale collections")
      }
      logger.info("📂 Synced collections")
      return true
    } catch {
      logger.error("❌ Failed to sync collections: \(error)")
      await report(.collections, progress: 1.0, onProgress: onProgress)
      return false
    }
  }

  private func syncSeriesIncremental(
    instanceId: String,
    since: Date,
    database: DatabaseOperator,
    onProgress: SyncProgressHandler
  ) async -> Bool {
    await report(
      .series,
      progress: 0.0,
      stage: .seriesIncremental,
      onProgress: onProgress
    )
    do {
      var page = 0
      var shouldContinue = true

      while shouldContinue {
        let result = try await SeriesService.getSeriesList(
          search: SeriesSearch(condition: nil),
          page: page,
          size: syncPageSize,
          sort: "lastModified,desc"
        )

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
          await database.upsertSeriesList(itemsToSync, instanceId: instanceId)
          await database.commit()
        }

        page += 1
        if result.last {
          shouldContinue = false
        }

        await report(
          .series,
          progress: shouldContinue ? estimatedIncrementalProgress(processedPages: page) : 1.0,
          stage: .seriesIncremental,
          onProgress: onProgress
        )
      }
      logger.info("📚 Synced series incrementally")
      return true
    } catch {
      logger.error("❌ Failed to sync series: \(error)")
      await report(
        .series,
        progress: 1.0,
        stage: .seriesIncremental,
        onProgress: onProgress
      )
      return false
    }
  }

  private func reconcileSeriesDeletions(
    instanceId: String,
    database: DatabaseOperator,
    onProgress: SyncProgressHandler
  ) async -> Bool {
    await report(
      .series,
      progress: 0.0,
      stage: .seriesReconcile,
      onProgress: onProgress
    )
    do {
      let localCount = await database.fetchTotalSeriesCount(instanceId: instanceId)
      do {
        let remoteCount = try await fetchRemoteSeriesCountForDeletionReconcile()
        if localCount <= remoteCount {
          logger.debug(
            "⏭️ Skipped series reconcile: localCount=\(localCount), remoteCount=\(remoteCount)"
          )
          await report(
            .series,
            progress: 1.0,
            stage: .seriesReconcile,
            onProgress: onProgress
          )
          return true
        }
      } catch {
        logger.warning(
          "⚠️ Failed to preflight series reconcile counts, fallback to full scan: \(error)"
        )
      }

      let remoteSeriesIds = try await fetchAllSeriesIdsForDeletionReconcile(
        onProgress: onProgress
      )
      let deletedCount = await database.deleteSeriesNotIn(
        remoteSeriesIds,
        instanceId: instanceId
      )
      if deletedCount > 0 {
        await database.commit()
        logger.info("🧹 Removed \(deletedCount) stale series")
      }
      return true
    } catch {
      logger.error("❌ Failed to reconcile stale series: \(error)")
      return false
    }
  }

  private func syncAllReadLists(
    instanceId: String,
    database: DatabaseOperator,
    onProgress: SyncProgressHandler
  ) async -> Bool {
    await report(.readLists, progress: 0.0, onProgress: onProgress)
    do {
      var page = 0
      var hasMore = true
      var totalPages = 1
      var remoteReadListIds = Set<String>()

      while hasMore {
        let result: Page<ReadList> = try await ReadListService.getReadLists(
          page: page,
          size: syncPageSize
        )
        remoteReadListIds.formUnion(result.content.map(\.id))
        await database.upsertReadLists(result.content, instanceId: instanceId)
        await database.commit()

        totalPages = max(result.totalPages, 1)
        hasMore = !result.last
        page += 1

        await report(
          .readLists,
          progress: Double(page) / Double(totalPages),
          onProgress: onProgress
        )
      }

      let deletedCount = await database.deleteReadListsNotIn(
        remoteReadListIds,
        instanceId: instanceId
      )
      if deletedCount > 0 {
        await database.commit()
        logger.info("🧹 Removed \(deletedCount) stale read lists")
      }
      logger.info("📖 Synced read lists")
      return true
    } catch {
      logger.error("❌ Failed to sync read lists: \(error)")
      await report(.readLists, progress: 1.0, onProgress: onProgress)
      return false
    }
  }

  private func syncBooksIncremental(
    instanceId: String,
    since: Date,
    database: DatabaseOperator,
    onProgress: SyncProgressHandler
  ) async -> Bool {
    await report(
      .books,
      progress: 0.0,
      stage: .booksIncremental,
      onProgress: onProgress
    )
    do {
      var page = 0
      var shouldContinue = true

      while shouldContinue {
        let result = try await BookService.getBooksList(
          search: BookSearch(condition: nil),
          page: page,
          size: syncPageSize,
          sort: "lastModified,desc"
        )

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
          await database.upsertBooks(itemsToSync, instanceId: instanceId)
          await database.commit()
        }

        page += 1
        if result.last {
          shouldContinue = false
        }

        await report(
          .books,
          progress: shouldContinue ? estimatedIncrementalProgress(processedPages: page) : 1.0,
          stage: .booksIncremental,
          onProgress: onProgress
        )
      }
      logger.info("📖 Synced books incrementally")
      return true
    } catch {
      logger.error("❌ Failed to sync books: \(error)")
      await report(
        .books,
        progress: 1.0,
        stage: .booksIncremental,
        onProgress: onProgress
      )
      return false
    }
  }

  private func reconcileBookDeletions(
    instanceId: String,
    database: DatabaseOperator,
    onProgress: SyncProgressHandler
  ) async -> Bool {
    await report(
      .books,
      progress: 0.0,
      stage: .booksReconcile,
      onProgress: onProgress
    )
    do {
      let localCount = await database.fetchTotalBooksCount(instanceId: instanceId)
      do {
        let remoteCount = try await fetchRemoteBookCountForDeletionReconcile()
        if localCount <= remoteCount {
          logger.debug(
            "⏭️ Skipped book reconcile: localCount=\(localCount), remoteCount=\(remoteCount)"
          )
          await report(
            .books,
            progress: 1.0,
            stage: .booksReconcile,
            onProgress: onProgress
          )
          return true
        }
      } catch {
        logger.warning(
          "⚠️ Failed to preflight book reconcile counts, fallback to full scan: \(error)"
        )
      }

      let remoteBookIds = try await fetchAllBookIdsForDeletionReconcile(
        onProgress: onProgress
      )
      let deletedCount = await database.deleteBooksNotIn(
        remoteBookIds,
        instanceId: instanceId
      )
      if deletedCount > 0 {
        await database.commit()
        let cleanupResult = await OfflineManager.shared.cleanupOrphanedFiles()
        if cleanupResult.deletedCount > 0 {
          logger.info(
            "🧹 Cleaned \(cleanupResult.deletedCount) orphaned offline directories after stale book removal"
          )
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
    let result = try await SeriesService.getSeriesList(
      search: SeriesSearch(condition: nil),
      page: 0,
      size: 1,
      sort: "lastModified,desc"
    )
    return result.totalElements
  }

  private func fetchRemoteBookCountForDeletionReconcile() async throws -> Int {
    let result = try await BookService.getBooksList(
      search: BookSearch(condition: nil),
      page: 0,
      size: 1,
      sort: "lastModified,desc"
    )
    return result.totalElements
  }

  private func fetchAllSeriesIdsForDeletionReconcile(
    onProgress: SyncProgressHandler
  ) async throws -> Set<String> {
    do {
      let result = try await SeriesService.getSeriesList(
        search: SeriesSearch(condition: nil),
        sort: "lastModified,desc",
        unpaged: true
      )
      await report(
        .series,
        progress: 1.0,
        stage: .seriesReconcile,
        onProgress: onProgress
      )
      return Set(result.content.map(\.id))
    } catch {
      logger.warning("⚠️ Unpaged series reconcile failed, fallback to paged scan: \(error)")
    }

    var page = 0
    var hasMore = true
    var ids = Set<String>()
    while hasMore {
      let result = try await SeriesService.getSeriesList(
        search: SeriesSearch(condition: nil),
        page: page,
        size: syncPageSize,
        sort: "lastModified,desc"
      )
      ids.formUnion(result.content.map(\.id))
      hasMore = !result.last
      page += 1
      await report(
        .series,
        progress: min(Double(page) / Double(max(result.totalPages, 1)), 1.0),
        stage: .seriesReconcile,
        onProgress: onProgress
      )
    }
    return ids
  }

  private func fetchAllBookIdsForDeletionReconcile(
    onProgress: SyncProgressHandler
  ) async throws -> Set<String> {
    do {
      let result = try await BookService.getBooksList(
        search: BookSearch(condition: nil),
        sort: "lastModified,desc",
        unpaged: true
      )
      await report(
        .books,
        progress: 1.0,
        stage: .booksReconcile,
        onProgress: onProgress
      )
      return Set(result.content.map(\.id))
    } catch {
      logger.warning("⚠️ Unpaged book reconcile failed, fallback to paged scan: \(error)")
    }

    var page = 0
    var hasMore = true
    var ids = Set<String>()
    while hasMore {
      let result = try await BookService.getBooksList(
        search: BookSearch(condition: nil),
        page: page,
        size: syncPageSize,
        sort: "lastModified,desc"
      )
      ids.formUnion(result.content.map(\.id))
      hasMore = !result.last
      page += 1
      await report(
        .books,
        progress: min(Double(page) / Double(max(result.totalPages, 1)), 1.0),
        stage: .booksReconcile,
        onProgress: onProgress
      )
    }
    return ids
  }

  private func estimatedIncrementalProgress(processedPages: Int) -> Double {
    guard processedPages > 0 else { return 0.0 }
    return min(Double(processedPages) / Double(processedPages + 2), 0.9)
  }

  private func report(
    _ phase: SyncPhase,
    progress: Double,
    stage: SyncStage? = nil,
    onProgress: SyncProgressHandler
  ) async {
    await onProgress(
      SyncProgress(
        phase: phase,
        phaseProgress: progress,
        stage: stage
      )
    )
  }
}
