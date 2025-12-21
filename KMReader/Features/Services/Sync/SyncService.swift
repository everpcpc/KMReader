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
      let libraries: [Library] = try await api.request(path: "/api/v1/libraries")
      let libraryInfos = libraries.map { LibraryInfo(id: $0.id, name: $0.name) }
      try await db.replaceLibraries(libraryInfos, for: instanceId)
      try await db.commit()
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
      try await db.commit()
      logger.info("📂 Synced collections")
    } catch {
      logger.error("❌ Failed to sync collections: \(error)")
    }
  }

  func syncReadLists(instanceId: String) async {
    do {
      let readLists: [ReadList] = try await api.request(path: "/api/v1/readlists")
      await db.upsertReadLists(readLists, instanceId: instanceId)
      try await db.commit()
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
        try await db.commit()
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
    sort: String,
    searchTerm: String?,
    browseOpts: SeriesBrowseOptions?
  ) async throws -> Page<Series> {
    let includeRead = browseOpts?.includeReadStatuses ?? []
    let excludeRead = browseOpts?.excludeReadStatuses ?? []
    let includeStatus = browseOpts?.includeSeriesStatuses ?? []
    let excludeStatus = browseOpts?.excludeSeriesStatuses ?? []
    let statusLogic = browseOpts?.seriesStatusLogic ?? .all
    let complete = browseOpts?.completeFilter ?? TriStateFilter<BoolTriStateFlag>()
    let oneshot = browseOpts?.oneshotFilter ?? TriStateFilter<BoolTriStateFlag>()
    let deleted = browseOpts?.deletedFilter ?? TriStateFilter<BoolTriStateFlag>()

    let result = try await SeriesService.shared.getSeries(
      libraryIds: libraryIds,
      page: page,
      size: size,
      sort: sort,
      includeReadStatuses: includeRead,
      excludeReadStatuses: excludeRead,
      includeSeriesStatuses: includeStatus,
      excludeSeriesStatuses: excludeStatus,
      seriesStatusLogic: statusLogic,
      completeFilter: complete,
      oneshotFilter: oneshot,
      deletedFilter: deleted,
      searchTerm: searchTerm
    )

    let instanceId = AppConfig.currentInstanceId
    await db.upsertSeriesList(result.content, instanceId: instanceId)
    try await db.commit()

    return result
  }

  func syncSeriesDetail(seriesId: String) async throws -> Series {
    let series = try await SeriesService.shared.getOneSeries(id: seriesId)
    let instanceId = AppConfig.currentInstanceId
    await db.upsertSeries(dto: series, instanceId: instanceId)
    try await db.commit()
    return series
  }

  func syncNewSeries(libraryIds: [String]?, page: Int, size: Int) async throws -> Page<Series> {
    let result = try await SeriesService.shared.getNewSeries(
      libraryIds: libraryIds, page: page, size: size)
    let instanceId = AppConfig.currentInstanceId
    await db.upsertSeriesList(result.content, instanceId: instanceId)
    try await db.commit()
    return result
  }

  func syncUpdatedSeries(libraryIds: [String]?, page: Int, size: Int) async throws -> Page<Series> {
    let result = try await SeriesService.shared.getUpdatedSeries(
      libraryIds: libraryIds, page: page, size: size)
    let instanceId = AppConfig.currentInstanceId
    await db.upsertSeriesList(result.content, instanceId: instanceId)
    try await db.commit()
    return result
  }

  func syncBooks(
    seriesId: String,
    page: Int,
    size: Int,
    browseOpts: BookBrowseOptions,
    libraryIds: [String]?
  ) async throws -> Page<Book> {
    let result = try await BookService.shared.getBooks(
      seriesId: seriesId,
      page: page,
      size: size,
      browseOpts: browseOpts,
      libraryIds: libraryIds
    )
    let instanceId = AppConfig.currentInstanceId
    await db.upsertBooks(result.content, instanceId: instanceId)
    try await db.commit()
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

    let instanceId = AppConfig.currentInstanceId
    await db.upsertBooks(result.content, instanceId: instanceId)
    try await db.commit()

    return result
  }

  func syncBooksOnDeck(libraryIds: [String]?, page: Int, size: Int) async throws -> Page<Book> {
    let result = try await BookService.shared.getBooksOnDeck(
      libraryIds: libraryIds, page: page, size: size)
    let instanceId = AppConfig.currentInstanceId
    await db.upsertBooks(result.content, instanceId: instanceId)
    try await db.commit()
    return result
  }

  func syncRecentlyReadBooks(libraryIds: [String]?, page: Int, size: Int) async throws -> Page<Book>
  {
    let result = try await BookService.shared.getRecentlyReadBooks(
      libraryIds: libraryIds, page: page, size: size)
    let instanceId = AppConfig.currentInstanceId
    await db.upsertBooks(result.content, instanceId: instanceId)
    try await db.commit()
    return result
  }

  func syncRecentlyAddedBooks(libraryIds: [String]?, page: Int, size: Int) async throws -> Page<
    Book
  > {
    let result = try await BookService.shared.getRecentlyAddedBooks(
      libraryIds: libraryIds, page: page, size: size)
    let instanceId = AppConfig.currentInstanceId
    await db.upsertBooks(result.content, instanceId: instanceId)
    try await db.commit()
    return result
  }

  func syncRecentlyReleasedBooks(libraryIds: [String]?, page: Int, size: Int) async throws -> Page<
    Book
  > {
    let result = try await BookService.shared.getRecentlyReleasedBooks(
      libraryIds: libraryIds, page: page, size: size)
    let instanceId = AppConfig.currentInstanceId
    await db.upsertBooks(result.content, instanceId: instanceId)
    try await db.commit()
    return result
  }

  func syncBook(bookId: String) async throws -> Book {
    let book = try await BookService.shared.getBook(id: bookId)
    let instanceId = AppConfig.currentInstanceId
    await db.upsertBook(dto: book, instanceId: instanceId)
    try await db.commit()
    return book
  }

  func syncNextBook(bookId: String, readListId: String? = nil) async -> Book? {
    do {
      if let book = try await BookService.shared.getNextBook(bookId: bookId, readListId: readListId)
      {
        let instanceId = AppConfig.currentInstanceId
        await db.upsertBook(dto: book, instanceId: instanceId)
        try await db.commit()
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
        let instanceId = AppConfig.currentInstanceId
        await db.upsertBook(dto: book, instanceId: instanceId)
        try await db.commit()
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
    let instanceId = AppConfig.currentInstanceId
    await db.upsertCollections(result.content, instanceId: instanceId)
    try await db.commit()
    return result
  }

  func syncCollection(id: String) async throws -> SeriesCollection {
    let collection = try await CollectionService.shared.getCollection(id: id)
    let instanceId = AppConfig.currentInstanceId
    await db.upsertCollection(dto: collection, instanceId: instanceId)
    try await db.commit()
    return collection
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
    let instanceId = AppConfig.currentInstanceId
    await db.upsertSeriesList(result.content, instanceId: instanceId)
    try await db.commit()
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
    let instanceId = AppConfig.currentInstanceId
    await db.upsertReadLists(result.content, instanceId: instanceId)
    try await db.commit()
    return result
  }

  func syncReadList(id: String) async throws -> ReadList {
    let readList = try await ReadListService.shared.getReadList(id: id)
    let instanceId = AppConfig.currentInstanceId
    await db.upsertReadList(dto: readList, instanceId: instanceId)
    try await db.commit()
    return readList
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
    let instanceId = AppConfig.currentInstanceId
    await db.upsertBooks(result.content, instanceId: instanceId)
    try await db.commit()
    return result
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
