//
// SyncService.swift
//
//

import Foundation
import OSLog
import SwiftData

@MainActor
class SyncService {
  static let shared = SyncService()

  private let logger = AppLogger(.sync)
  private let syncPageSize = 1000
  private let recentlyReadSyncPageSize = 200

  private init() {}

  func syncAll(instanceId: String) async {
    logger.info("🔄 Starting full sync for instance: \(instanceId)")
    await syncLibraries(instanceId: instanceId)
    await syncCollections(instanceId: instanceId)
    await syncReadLists(instanceId: instanceId)
    await syncDashboard(instanceId: instanceId)
    logger.info("✅ Full sync completed for instance: \(instanceId)")
  }

  func syncLibraries(instanceId: String) async {
    do {
      let database = try await DatabaseOperator.database()
      let libraries = try await LibraryService.shared.getLibraries()
      let libraryInfos = libraries.map { LibraryInfo(id: $0.id, name: $0.name) }
      try await database.replaceLibraries(libraryInfos, for: instanceId)
      await database.commit()
      logger.info("📚 Synced \(libraries.count) libraries")
    } catch {
      logger.error("❌ Failed to sync libraries: \(error)")
    }
  }

  func syncCollections(instanceId: String) async {
    do {
      let database = try await DatabaseOperator.database()
      var page = 0
      var hasMore = true
      var remoteCollectionIds = Set<String>()
      while hasMore {
        let result: Page<SeriesCollection> = try await CollectionService.shared.getCollections(
          page: page, size: syncPageSize)
        remoteCollectionIds.formUnion(result.content.map(\.id))
        await database.upsertCollections(result.content, instanceId: instanceId)
        hasMore = !result.last
        page += 1
      }
      let deletedCount = await database.deleteCollectionsNotIn(
        remoteCollectionIds,
        instanceId: instanceId
      )
      await database.commit()
      if deletedCount > 0 {
        logger.info("🧹 Removed \(deletedCount) stale collections")
      }
      logger.info("📂 Synced collections")
    } catch {
      logger.error("❌ Failed to sync collections: \(error)")
    }
  }

  func syncReadLists(instanceId: String) async {
    do {
      let database = try await DatabaseOperator.database()
      var page = 0
      var hasMore = true
      var remoteReadListIds = Set<String>()
      while hasMore {
        let result: Page<ReadList> = try await ReadListService.shared.getReadLists(
          page: page, size: syncPageSize)
        remoteReadListIds.formUnion(result.content.map(\.id))
        await database.upsertReadLists(result.content, instanceId: instanceId)
        hasMore = !result.last
        page += 1
      }
      let deletedCount = await database.deleteReadListsNotIn(
        remoteReadListIds,
        instanceId: instanceId
      )
      await database.commit()
      if deletedCount > 0 {
        logger.info("🧹 Removed \(deletedCount) stale read lists")
      }
      logger.info("📖 Synced readlists")
    } catch {
      logger.error("❌ Failed to sync readlists: \(error)")
    }
  }

  func syncSeries(libraryId: String, instanceId: String) async {
    do {
      let database = try await DatabaseOperator.database()
      var page = 0
      var hasMore = true
      let filters = SeriesSearchFilters(libraryIds: [libraryId])
      let condition = SeriesSearch.buildCondition(filters: filters)
      let search = SeriesSearch(condition: condition)
      while hasMore {
        let result = try await SeriesService.shared.getSeriesList(
          search: search, page: page, size: syncPageSize)
        await database.upsertSeriesList(result.content, instanceId: instanceId)
        hasMore = !result.last
        page += 1
        await database.commit()
      }
      logger.info("📚 Synced series for library \(libraryId)")
    } catch {
      logger.error("❌ Failed to sync series for library \(libraryId): \(error)")
    }
  }

  func syncSeriesPage(
    libraryIds: [String]?,
    page: Int,
    size: Int,
    searchTerm: String?,
    browseOpts: SeriesBrowseOptions?
  ) async throws -> Page<Series> {
    let database = try await DatabaseOperator.database()
    let result = try await SeriesService.shared.getSeries(
      libraryIds: libraryIds,
      page: page,
      size: size,
      browseOpts: browseOpts ?? SeriesBrowseOptions(),
      searchTerm: searchTerm
    )

    let instanceId = AppConfig.current.instanceId
    await database.upsertSeriesList(result.content, instanceId: instanceId)
    await database.commit()

    return result
  }

  func syncSeriesDetail(seriesId: String) async throws -> Series {
    let database = try await DatabaseOperator.database()
    do {
      let series = try await SeriesService.shared.getOneSeries(id: seriesId)
      let instanceId = AppConfig.current.instanceId
      await database.upsertSeries(dto: series, instanceId: instanceId)
      await database.commit()
      return series
    } catch APIError.notFound {
      let instanceId = AppConfig.current.instanceId
      await database.deleteSeries(id: seriesId, instanceId: instanceId)
      await database.commit()
      throw APIError.notFound(message: "Series not found", url: nil, response: nil, request: nil)
    }
  }

  func syncNewSeries(libraryIds: [String]?, page: Int, size: Int) async throws -> Page<Series> {
    let database = try await DatabaseOperator.database()
    let result = try await SeriesService.shared.getNewSeries(
      libraryIds: libraryIds, page: page, size: size)
    let instanceId = AppConfig.current.instanceId
    await database.upsertSeriesList(result.content, instanceId: instanceId)
    await database.commit()
    return result
  }

  func syncUpdatedSeries(libraryIds: [String]?, page: Int, size: Int) async throws -> Page<Series> {
    let database = try await DatabaseOperator.database()
    let result = try await SeriesService.shared.getUpdatedSeries(
      libraryIds: libraryIds, page: page, size: size)
    let instanceId = AppConfig.current.instanceId
    await database.upsertSeriesList(result.content, instanceId: instanceId)
    await database.commit()
    return result
  }

  func syncBooks(
    seriesId: String,
    page: Int,
    size: Int,
    browseOpts: BookBrowseOptions? = nil,
  ) async throws -> Page<Book> {
    let database = try await DatabaseOperator.database()
    let result = try await BookService.shared.getBooks(
      seriesId: seriesId,
      page: page,
      size: size,
      browseOpts: browseOpts ?? BookBrowseOptions()
    )
    let instanceId = AppConfig.current.instanceId
    await database.upsertBooks(result.content, instanceId: instanceId)
    await database.commit()
    return result
  }

  func syncBooksList(
    search: BookSearch,
    page: Int,
    size: Int,
    sort: String?
  ) async throws -> Page<Book> {
    let database = try await DatabaseOperator.database()
    let result = try await BookService.shared.getBooksList(
      search: search,
      page: page,
      size: size,
      sort: sort
    )

    let instanceId = AppConfig.current.instanceId
    await database.upsertBooks(result.content, instanceId: instanceId)
    await database.commit()

    return result
  }

  func syncBrowseBooks(
    libraryIds: [String]?,
    page: Int,
    size: Int,
    searchTerm: String?,
    browseOpts: BookBrowseOptions
  ) async throws -> Page<Book> {
    let database = try await DatabaseOperator.database()
    let result = try await BookService.shared.getBrowseBooks(
      libraryIds: libraryIds,
      page: page,
      size: size,
      browseOpts: browseOpts,
      searchTerm: searchTerm
    )

    let instanceId = AppConfig.current.instanceId
    await database.upsertBooks(result.content, instanceId: instanceId)
    await database.commit()

    return result
  }

  func syncBooksOnDeck(libraryIds: [String]?, page: Int, size: Int) async throws -> Page<Book> {
    let database = try await DatabaseOperator.database()
    let result = try await BookService.shared.getBooksOnDeck(
      libraryIds: libraryIds, page: page, size: size)
    let instanceId = AppConfig.current.instanceId
    await database.upsertBooks(result.content, instanceId: instanceId)
    await database.commit()
    return result
  }

  func syncRecentlyReadBooks(libraryIds: [String]?, page: Int, size: Int) async throws -> Page<Book> {
    let database = try await DatabaseOperator.database()
    let result = try await BookService.shared.getRecentlyReadBooks(
      libraryIds: libraryIds, page: page, size: size)
    let instanceId = AppConfig.current.instanceId
    await database.upsertBooks(result.content, instanceId: instanceId)
    await database.commit()
    return result
  }

  func syncLatestRecentlyReadProgress() async -> Bool {
    let instanceId = AppConfig.current.instanceId
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
        let result = try await BookService.shared.getBooksList(
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

  func syncRecentlyAddedBooks(libraryIds: [String]?, page: Int, size: Int) async throws -> Page<
    Book
  > {
    let database = try await DatabaseOperator.database()
    let result = try await BookService.shared.getRecentlyAddedBooks(
      libraryIds: libraryIds, page: page, size: size)
    let instanceId = AppConfig.current.instanceId
    await database.upsertBooks(result.content, instanceId: instanceId)
    await database.commit()
    return result
  }

  func syncRecentlyReleasedBooks(libraryIds: [String]?, page: Int, size: Int) async throws -> Page<
    Book
  > {
    let database = try await DatabaseOperator.database()
    let result = try await BookService.shared.getRecentlyReleasedBooks(
      libraryIds: libraryIds, page: page, size: size)
    let instanceId = AppConfig.current.instanceId
    await database.upsertBooks(result.content, instanceId: instanceId)
    await database.commit()
    return result
  }

  /// Sync all books for a series (all pages) - used before offline policy operations
  func syncAllSeriesBooks(seriesId: String) async throws {
    let database = try await DatabaseOperator.database()
    let instanceId = AppConfig.current.instanceId
    var page = 0
    var hasMore = true

    while hasMore {
      let result = try await BookService.shared.getBooks(
        seriesId: seriesId,
        page: page,
        size: syncPageSize,
        browseOpts: BookBrowseOptions()
      )
      await database.upsertBooks(result.content, instanceId: instanceId)
      hasMore = !result.last
      page += 1
    }
    await database.commit()
    logger.info("📚 Synced all books for series \(seriesId)")
  }

  /// Sync all books for a readlist (all pages) - used before offline policy operations
  func syncAllReadListBooks(readListId: String) async throws {
    let database = try await DatabaseOperator.database()
    let instanceId = AppConfig.current.instanceId
    var page = 0
    var hasMore = true

    while hasMore {
      let result = try await ReadListService.shared.getReadListBooks(
        readListId: readListId,
        page: page,
        size: syncPageSize,
        browseOpts: ReadListBookBrowseOptions(),
        libraryIds: nil
      )
      await database.upsertBooks(result.content, instanceId: instanceId)
      hasMore = !result.last
      page += 1
    }
    await database.commit()
    logger.info("📖 Synced all books for readlist \(readListId)")
  }

  func syncBook(bookId: String) async throws -> Book {
    let database = try await DatabaseOperator.database()
    do {
      let book = try await BookService.shared.getBook(id: bookId)
      let instanceId = AppConfig.current.instanceId
      await database.upsertBook(dto: book, instanceId: instanceId)
      await database.commit()
      return book
    } catch APIError.notFound {
      let instanceId = AppConfig.current.instanceId
      await database.deleteBook(id: bookId, instanceId: instanceId)
      await database.commit()
      throw APIError.notFound(message: "Book not found", url: nil, response: nil, request: nil)
    }
  }

  func syncBookAndSeries(bookId: String, seriesId: String) async throws {
    let database = try await DatabaseOperator.database()
    async let bookTask = BookService.shared.getBook(id: bookId)
    async let seriesTask = SeriesService.shared.getOneSeries(id: seriesId)

    let book = try await bookTask
    let series = try await seriesTask

    let instanceId = AppConfig.current.instanceId
    await database.upsertBook(dto: book, instanceId: instanceId)
    await database.upsertSeries(dto: series, instanceId: instanceId)
    await database.commit()
  }

  /// Batch sync multiple books and series concurrently with a single commit
  func syncVisitedItems(bookIds: Set<String>, seriesIds: Set<String>) async {
    guard !bookIds.isEmpty || !seriesIds.isEmpty else { return }

    do {
      let database = try await DatabaseOperator.database()
      let instanceId = AppConfig.current.instanceId

      // Fetch all books and series concurrently
      await withTaskGroup(of: Void.self) { group in
        for bookId in bookIds {
          group.addTask {
            do {
              let book = try await BookService.shared.getBook(id: bookId)
              await database.upsertBook(dto: book, instanceId: instanceId)
            } catch {
              // Silently ignore individual fetch failures
            }
          }
        }

        for seriesId in seriesIds {
          group.addTask {
            do {
              let series = try await SeriesService.shared.getOneSeries(id: seriesId)
              await database.upsertSeries(dto: series, instanceId: instanceId)
            } catch {
              // Silently ignore individual fetch failures
            }
          }
        }
      }

      // Single commit after all fetches complete
      await database.commit()
    } catch {
      logger.error("❌ Failed to sync visited items: \(error)")
    }
  }

  func syncNextBook(bookId: String, readListId: String? = nil) async -> Book? {
    do {
      let database = try await DatabaseOperator.database()
      if let book = try await BookService.shared.getNextBook(bookId: bookId, readListId: readListId) {
        let instanceId = AppConfig.current.instanceId
        await database.upsertBook(dto: book, instanceId: instanceId)
        await database.commit()
        return book
      }
    } catch {
      logger.error("❌ Failed to sync next book: \(error)")
    }
    return nil
  }

  func syncPreviousBook(bookId: String, readListId: String? = nil) async -> Book? {
    do {
      let database = try await DatabaseOperator.database()
      if let book = try await BookService.shared.getPreviousBook(
        bookId: bookId,
        readListId: readListId
      ) {
        let instanceId = AppConfig.current.instanceId
        await database.upsertBook(dto: book, instanceId: instanceId)
        await database.commit()
        return book
      }
    } catch {
      logger.error("❌ Failed to sync previous book: \(error)")
    }
    return nil
  }

  func syncCollections(
    libraryIds: [String]?,
    page: Int,
    size: Int,
    sort: String?,
    search: String?
  ) async throws -> Page<SeriesCollection> {
    let database = try await DatabaseOperator.database()
    let result = try await CollectionService.shared.getCollections(
      libraryIds: libraryIds,
      page: page,
      size: size,
      sort: sort,
      search: search
    )
    let instanceId = AppConfig.current.instanceId
    await database.upsertCollections(result.content, instanceId: instanceId)
    await database.commit()
    return result
  }

  func syncCollection(id: String) async throws -> SeriesCollection {
    let database = try await DatabaseOperator.database()
    do {
      let collection = try await CollectionService.shared.getCollection(id: id)
      let instanceId = AppConfig.current.instanceId
      await database.upsertCollection(dto: collection, instanceId: instanceId)
      await database.commit()
      return collection
    } catch APIError.notFound {
      let instanceId = AppConfig.current.instanceId
      await database.deleteCollection(id: id, instanceId: instanceId)
      await database.commit()
      throw APIError.notFound(message: "Collection not found", url: nil, response: nil, request: nil)
    }
  }

  func syncSeriesCollections(seriesId: String) async {
    do {
      let database = try await DatabaseOperator.database()
      let collections = try await SeriesService.shared.getSeriesCollections(seriesId: seriesId)
      let instanceId = AppConfig.current.instanceId
      await database.upsertCollections(collections, instanceId: instanceId)
      // Update the series' cached collectionIds
      let collectionIds = collections.map { $0.id }
      await database.updateSeriesCollectionIds(
        seriesId: seriesId, collectionIds: collectionIds, instanceId: instanceId)
      await database.commit()
    } catch {
      logger.error("❌ Failed to sync series collections: \(error)")
    }
  }

  func syncCollectionSeries(
    collectionId: String,
    page: Int,
    size: Int,
    browseOpts: CollectionSeriesBrowseOptions,
    libraryIds: [String]?
  ) async throws -> Page<Series> {
    let database = try await DatabaseOperator.database()
    let result = try await CollectionService.shared.getCollectionSeries(
      collectionId: collectionId,
      page: page,
      size: size,
      browseOpts: browseOpts,
      libraryIds: libraryIds
    )
    let instanceId = AppConfig.current.instanceId
    await database.upsertSeriesList(result.content, instanceId: instanceId)
    await database.commit()
    return result
  }

  func syncReadLists(
    libraryIds: [String]?,
    page: Int,
    size: Int,
    sort: String?,
    search: String?
  ) async throws -> Page<ReadList> {
    let database = try await DatabaseOperator.database()
    let result = try await ReadListService.shared.getReadLists(
      libraryIds: libraryIds,
      page: page,
      size: size,
      sort: sort,
      search: search
    )
    let instanceId = AppConfig.current.instanceId
    await database.upsertReadLists(result.content, instanceId: instanceId)
    await database.commit()
    return result
  }

  func syncReadList(id: String) async throws -> ReadList {
    let database = try await DatabaseOperator.database()
    do {
      let readList = try await ReadListService.shared.getReadList(id: id)
      let instanceId = AppConfig.current.instanceId
      await database.upsertReadList(dto: readList, instanceId: instanceId)
      await database.commit()
      return readList
    } catch APIError.notFound {
      let instanceId = AppConfig.current.instanceId
      await database.deleteReadList(id: id, instanceId: instanceId)
      await database.commit()
      throw APIError.notFound(message: "Read list not found", url: nil, response: nil, request: nil)
    }
  }

  func syncReadListBooks(
    readListId: String,
    page: Int,
    size: Int,
    browseOpts: ReadListBookBrowseOptions,
    libraryIds: [String]?
  ) async throws -> Page<Book> {
    let database = try await DatabaseOperator.database()
    let result = try await ReadListService.shared.getReadListBooks(
      readListId: readListId,
      page: page,
      size: size,
      browseOpts: browseOpts,
      libraryIds: libraryIds
    )
    let instanceId = AppConfig.current.instanceId
    await database.upsertBooks(result.content, instanceId: instanceId)
    await database.commit()
    return result
  }

  func syncBookReadLists(bookId: String) async {
    do {
      let database = try await DatabaseOperator.database()
      let readLists = try await BookService.shared.getReadListsForBook(bookId: bookId)
      let instanceId = AppConfig.current.instanceId
      await database.upsertReadLists(readLists, instanceId: instanceId)
      // Update the book's cached readListIds
      let readListIds = readLists.map { $0.id }
      await database.updateBookReadListIds(
        bookId: bookId, readListIds: readListIds, instanceId: instanceId)
      await database.commit()
    } catch {
      logger.error("❌ Failed to sync book read lists: \(error)")
    }
  }

  func syncDashboard(instanceId: String) async {
    guard let database = await DatabaseOperator.databaseIfConfigured() else {
      logger.warning("⚠️ Failed to get database operator for dashboard sync")
      return
    }

    let libraryIds = await database.fetchLibraries(instanceId: instanceId).map(\.id)
    _ = try? await syncBooksOnDeck(libraryIds: libraryIds, page: 0, size: 20)
    _ = try? await syncRecentlyAddedBooks(libraryIds: libraryIds, page: 0, size: 20)
    _ = try? await syncRecentlyReadBooks(libraryIds: libraryIds, page: 0, size: 20)
    _ = try? await syncRecentlyReleasedBooks(libraryIds: libraryIds, page: 0, size: 20)
    _ = try? await syncNewSeries(libraryIds: libraryIds, page: 0, size: 20)
    _ = try? await syncUpdatedSeries(libraryIds: libraryIds, page: 0, size: 20)
  }

  // MARK: - Cleanup

  func clearInstanceData(instanceId: String) async {
    do {
      let database = try await DatabaseOperator.database()
      await database.clearInstanceData(instanceId: instanceId)
    } catch {
      logger.error("❌ Failed to clear instance data: \(error)")
    }
  }
}
