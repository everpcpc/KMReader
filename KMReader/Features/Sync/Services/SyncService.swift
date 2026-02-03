//
//  SyncService.swift
//  KMReader
//
//  Created by Komga iOS Client
//

import Foundation
import OSLog
import SwiftData

@MainActor
class SyncService {
  static let shared = SyncService()

  private let api = APIClient.shared
  private let logger = AppLogger(.sync)

  private init() {}

  private var db: DatabaseOperator {
    DatabaseOperator.shared
  }

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
      let libraries = try await LibraryService.shared.getLibraries()
      let libraryInfos = libraries.map { LibraryInfo(id: $0.id, name: $0.name) }
      try await db.replaceLibraries(libraryInfos, for: instanceId)
      await db.commit()
      logger.info("📚 Synced \(libraries.count) libraries")
    } catch {
      logger.error("❌ Failed to sync libraries: \(error)")
    }
  }

  func syncCollections(instanceId: String) async {
    do {
      var page = 0
      var hasMore = true
      while hasMore {
        let result: Page<SeriesCollection> = try await CollectionService.shared.getCollections(
          page: page, size: 500)
        await db.upsertCollections(result.content, instanceId: instanceId)
        hasMore = !result.last
        page += 1
      }
      await db.commit()
      logger.info("📂 Synced collections")
    } catch {
      logger.error("❌ Failed to sync collections: \(error)")
    }
  }

  func syncReadLists(instanceId: String) async {
    do {
      var page = 0
      var hasMore = true
      while hasMore {
        let result: Page<ReadList> = try await ReadListService.shared.getReadLists(
          page: page, size: 500)
        await db.upsertReadLists(result.content, instanceId: instanceId)
        hasMore = !result.last
        page += 1
      }
      await db.commit()
      logger.info("📖 Synced readlists")
    } catch {
      logger.error("❌ Failed to sync readlists: \(error)")
    }
  }

  func syncSeries(libraryId: String, instanceId: String) async {
    do {
      var page = 0
      var hasMore = true
      let filters = SeriesSearchFilters(libraryIds: [libraryId])
      let condition = SeriesSearch.buildCondition(filters: filters)
      let search = SeriesSearch(condition: condition)
      while hasMore {
        let result = try await SeriesService.shared.getSeriesList(
          search: search, page: page, size: 100)
        await db.upsertSeriesList(result.content, instanceId: instanceId)
        hasMore = !result.last
        page += 1
        await db.commit()
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
    let result = try await SeriesService.shared.getSeries(
      libraryIds: libraryIds,
      page: page,
      size: size,
      browseOpts: browseOpts ?? SeriesBrowseOptions(),
      searchTerm: searchTerm
    )

    let instanceId = AppConfig.current.instanceId
    await db.upsertSeriesList(result.content, instanceId: instanceId)
    await db.commit()

    return result
  }

  func syncSeriesDetail(seriesId: String) async throws -> Series {
    do {
      let series = try await SeriesService.shared.getOneSeries(id: seriesId)
      let instanceId = AppConfig.current.instanceId
      await db.upsertSeries(dto: series, instanceId: instanceId)
      await db.commit()
      return series
    } catch APIError.notFound {
      let instanceId = AppConfig.current.instanceId
      await db.deleteSeries(id: seriesId, instanceId: instanceId)
      await db.commit()
      throw APIError.notFound(message: "Series not found", url: nil, response: nil, request: nil)
    }
  }

  func syncNewSeries(libraryIds: [String]?, page: Int, size: Int) async throws -> Page<Series> {
    let result = try await SeriesService.shared.getNewSeries(
      libraryIds: libraryIds, page: page, size: size)
    let instanceId = AppConfig.current.instanceId
    await db.upsertSeriesList(result.content, instanceId: instanceId)
    await db.commit()
    return result
  }

  func syncUpdatedSeries(libraryIds: [String]?, page: Int, size: Int) async throws -> Page<Series> {
    let result = try await SeriesService.shared.getUpdatedSeries(
      libraryIds: libraryIds, page: page, size: size)
    let instanceId = AppConfig.current.instanceId
    await db.upsertSeriesList(result.content, instanceId: instanceId)
    await db.commit()
    return result
  }

  func syncBooks(
    seriesId: String,
    page: Int,
    size: Int,
    browseOpts: BookBrowseOptions? = nil,
  ) async throws -> Page<Book> {
    let result = try await BookService.shared.getBooks(
      seriesId: seriesId,
      page: page,
      size: size,
      browseOpts: browseOpts ?? BookBrowseOptions()
    )
    let instanceId = AppConfig.current.instanceId
    await db.upsertBooks(result.content, instanceId: instanceId)
    await db.commit()
    return result
  }

  func syncBooksList(
    search: BookSearch,
    page: Int,
    size: Int,
    sort: String?
  ) async throws -> Page<Book> {
    let result = try await BookService.shared.getBooksList(
      search: search,
      page: page,
      size: size,
      sort: sort
    )

    let instanceId = AppConfig.current.instanceId
    await db.upsertBooks(result.content, instanceId: instanceId)
    await db.commit()

    return result
  }

  func syncBrowseBooks(
    libraryIds: [String]?,
    page: Int,
    size: Int,
    searchTerm: String?,
    browseOpts: BookBrowseOptions
  ) async throws -> Page<Book> {
    let result = try await BookService.shared.getBrowseBooks(
      libraryIds: libraryIds,
      page: page,
      size: size,
      browseOpts: browseOpts,
      searchTerm: searchTerm
    )

    let instanceId = AppConfig.current.instanceId
    await db.upsertBooks(result.content, instanceId: instanceId)
    await db.commit()

    return result
  }

  func syncBooksOnDeck(libraryIds: [String]?, page: Int, size: Int) async throws -> Page<Book> {
    let result = try await BookService.shared.getBooksOnDeck(
      libraryIds: libraryIds, page: page, size: size)
    let instanceId = AppConfig.current.instanceId
    await db.upsertBooks(result.content, instanceId: instanceId)
    await db.commit()
    return result
  }

  func syncRecentlyReadBooks(libraryIds: [String]?, page: Int, size: Int) async throws -> Page<Book> {
    let result = try await BookService.shared.getRecentlyReadBooks(
      libraryIds: libraryIds, page: page, size: size)
    let instanceId = AppConfig.current.instanceId
    await db.upsertBooks(result.content, instanceId: instanceId)
    await db.commit()
    return result
  }

  func syncRecentlyAddedBooks(libraryIds: [String]?, page: Int, size: Int) async throws -> Page<
    Book
  > {
    let result = try await BookService.shared.getRecentlyAddedBooks(
      libraryIds: libraryIds, page: page, size: size)
    let instanceId = AppConfig.current.instanceId
    await db.upsertBooks(result.content, instanceId: instanceId)
    await db.commit()
    return result
  }

  func syncRecentlyReleasedBooks(libraryIds: [String]?, page: Int, size: Int) async throws -> Page<
    Book
  > {
    let result = try await BookService.shared.getRecentlyReleasedBooks(
      libraryIds: libraryIds, page: page, size: size)
    let instanceId = AppConfig.current.instanceId
    await db.upsertBooks(result.content, instanceId: instanceId)
    await db.commit()
    return result
  }

  /// Sync all books for a series (all pages) - used before offline policy operations
  func syncAllSeriesBooks(seriesId: String) async throws {
    let instanceId = AppConfig.current.instanceId
    var page = 0
    var hasMore = true

    while hasMore {
      let result = try await BookService.shared.getBooks(
        seriesId: seriesId,
        page: page,
        size: 100,
        browseOpts: BookBrowseOptions()
      )
      await db.upsertBooks(result.content, instanceId: instanceId)
      hasMore = !result.last
      page += 1
    }
    await db.commit()
    logger.info("📚 Synced all books for series \(seriesId)")
  }

  /// Sync all books for a readlist (all pages) - used before offline policy operations
  func syncAllReadListBooks(readListId: String) async throws {
    let instanceId = AppConfig.current.instanceId
    var page = 0
    var hasMore = true

    while hasMore {
      let result = try await ReadListService.shared.getReadListBooks(
        readListId: readListId,
        page: page,
        size: 100,
        browseOpts: ReadListBookBrowseOptions(),
        libraryIds: nil
      )
      await db.upsertBooks(result.content, instanceId: instanceId)
      hasMore = !result.last
      page += 1
    }
    await db.commit()
    logger.info("📖 Synced all books for readlist \(readListId)")
  }

  func syncBook(bookId: String) async throws -> Book {
    do {
      let book = try await BookService.shared.getBook(id: bookId)
      let instanceId = AppConfig.current.instanceId
      await db.upsertBook(dto: book, instanceId: instanceId)
      await db.commit()
      return book
    } catch APIError.notFound {
      let instanceId = AppConfig.current.instanceId
      await db.deleteBook(id: bookId, instanceId: instanceId)
      await db.commit()
      throw APIError.notFound(message: "Book not found", url: nil, response: nil, request: nil)
    }
  }

  func syncBookAndSeries(bookId: String, seriesId: String) async throws {
    async let bookTask = BookService.shared.getBook(id: bookId)
    async let seriesTask = SeriesService.shared.getOneSeries(id: seriesId)

    let book = try await bookTask
    let series = try await seriesTask

    let instanceId = AppConfig.current.instanceId
    await db.upsertBook(dto: book, instanceId: instanceId)
    await db.upsertSeries(dto: series, instanceId: instanceId)
    await db.commit()
  }

  /// Batch sync multiple books and series concurrently with a single commit
  func syncVisitedItems(bookIds: Set<String>, seriesIds: Set<String>) async {
    guard !bookIds.isEmpty || !seriesIds.isEmpty else { return }

    let instanceId = AppConfig.current.instanceId

    // Fetch all books and series concurrently
    await withTaskGroup(of: Void.self) { group in
      for bookId in bookIds {
        group.addTask {
          do {
            let book = try await BookService.shared.getBook(id: bookId)
            await self.db.upsertBook(dto: book, instanceId: instanceId)
          } catch {
            // Silently ignore individual fetch failures
          }
        }
      }

      for seriesId in seriesIds {
        group.addTask {
          do {
            let series = try await SeriesService.shared.getOneSeries(id: seriesId)
            await self.db.upsertSeries(dto: series, instanceId: instanceId)
          } catch {
            // Silently ignore individual fetch failures
          }
        }
      }
    }

    // Single commit after all fetches complete
    await db.commit()
  }

  func syncNextBook(bookId: String, readListId: String? = nil) async -> Book? {
    do {
      if let book = try await BookService.shared.getNextBook(bookId: bookId, readListId: readListId) {
        let instanceId = AppConfig.current.instanceId
        await db.upsertBook(dto: book, instanceId: instanceId)
        await db.commit()
        return book
      }
    } catch {
      logger.error("❌ Failed to sync next book: \(error)")
    }
    return nil
  }

  func syncPreviousBook(bookId: String) async -> Book? {
    do {
      if let book = try await BookService.shared.getPreviousBook(bookId: bookId) {
        let instanceId = AppConfig.current.instanceId
        await db.upsertBook(dto: book, instanceId: instanceId)
        await db.commit()
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
    let result = try await CollectionService.shared.getCollections(
      libraryIds: libraryIds,
      page: page,
      size: size,
      sort: sort,
      search: search
    )
    let instanceId = AppConfig.current.instanceId
    await db.upsertCollections(result.content, instanceId: instanceId)
    await db.commit()
    return result
  }

  func syncCollection(id: String) async throws -> SeriesCollection {
    do {
      let collection = try await CollectionService.shared.getCollection(id: id)
      let instanceId = AppConfig.current.instanceId
      await db.upsertCollection(dto: collection, instanceId: instanceId)
      await db.commit()
      return collection
    } catch APIError.notFound {
      let instanceId = AppConfig.current.instanceId
      await db.deleteCollection(id: id, instanceId: instanceId)
      await db.commit()
      throw APIError.notFound(message: "Collection not found", url: nil, response: nil, request: nil)
    }
  }

  func syncSeriesCollections(seriesId: String) async {
    do {
      let collections = try await SeriesService.shared.getSeriesCollections(seriesId: seriesId)
      let instanceId = AppConfig.current.instanceId
      await db.upsertCollections(collections, instanceId: instanceId)
      // Update the series' cached collectionIds
      let collectionIds = collections.map { $0.id }
      await db.updateSeriesCollectionIds(
        seriesId: seriesId, collectionIds: collectionIds, instanceId: instanceId)
      await db.commit()
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
    let result = try await CollectionService.shared.getCollectionSeries(
      collectionId: collectionId,
      page: page,
      size: size,
      browseOpts: browseOpts,
      libraryIds: libraryIds
    )
    let instanceId = AppConfig.current.instanceId
    await db.upsertSeriesList(result.content, instanceId: instanceId)
    await db.commit()
    return result
  }

  func syncReadLists(
    libraryIds: [String]?,
    page: Int,
    size: Int,
    sort: String?,
    search: String?
  ) async throws -> Page<ReadList> {
    let result = try await ReadListService.shared.getReadLists(
      libraryIds: libraryIds,
      page: page,
      size: size,
      sort: sort,
      search: search
    )
    let instanceId = AppConfig.current.instanceId
    await db.upsertReadLists(result.content, instanceId: instanceId)
    await db.commit()
    return result
  }

  func syncReadList(id: String) async throws -> ReadList {
    do {
      let readList = try await ReadListService.shared.getReadList(id: id)
      let instanceId = AppConfig.current.instanceId
      await db.upsertReadList(dto: readList, instanceId: instanceId)
      await db.commit()
      return readList
    } catch APIError.notFound {
      let instanceId = AppConfig.current.instanceId
      await db.deleteReadList(id: id, instanceId: instanceId)
      await db.commit()
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
    let result = try await ReadListService.shared.getReadListBooks(
      readListId: readListId,
      page: page,
      size: size,
      browseOpts: browseOpts,
      libraryIds: libraryIds
    )
    let instanceId = AppConfig.current.instanceId
    await db.upsertBooks(result.content, instanceId: instanceId)
    await db.commit()
    return result
  }

  func syncBookReadLists(bookId: String) async {
    do {
      let readLists = try await BookService.shared.getReadListsForBook(bookId: bookId)
      let instanceId = AppConfig.current.instanceId
      await db.upsertReadLists(readLists, instanceId: instanceId)
      // Update the book's cached readListIds
      let readListIds = readLists.map { $0.id }
      await db.updateBookReadListIds(
        bookId: bookId, readListIds: readListIds, instanceId: instanceId)
      await db.commit()
    } catch {
      logger.error("❌ Failed to sync book read lists: \(error)")
    }
  }

  func syncDashboard(instanceId: String) async {
    let libraryIds = await db.fetchLibraries(instanceId: instanceId).map { $0.id }
    _ = try? await syncBooksOnDeck(libraryIds: libraryIds, page: 0, size: 20)
    _ = try? await syncRecentlyAddedBooks(libraryIds: libraryIds, page: 0, size: 20)
    _ = try? await syncRecentlyReadBooks(libraryIds: libraryIds, page: 0, size: 20)
    _ = try? await syncRecentlyReleasedBooks(libraryIds: libraryIds, page: 0, size: 20)
    _ = try? await syncNewSeries(libraryIds: libraryIds, page: 0, size: 20)
    _ = try? await syncUpdatedSeries(libraryIds: libraryIds, page: 0, size: 20)
  }

  // MARK: - Cleanup

  func clearInstanceData(instanceId: String) async {
    await db.clearInstanceData(instanceId: instanceId)
  }
}
