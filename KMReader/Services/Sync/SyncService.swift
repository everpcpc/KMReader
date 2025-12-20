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
  private var container: ModelContainer?
  private let api = APIClient.shared
  private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "KMReader", category: "SyncService")

  private init() {}

  func configure(with container: ModelContainer) {
    self.container = container
  }

  private func makeContext() -> ModelContext? {
    guard let container = container else {
      logger.error("ModelContainer not configured")
      return nil
    }
    return ModelContext(container)
  }

  func syncAll(instanceId: String) async {
    logger.info("Starting full sync for instance: \(instanceId)")
    await syncLibraries(instanceId: instanceId)
    await syncCollections(instanceId: instanceId)
    await syncReadLists(instanceId: instanceId)
    await syncDashboard(instanceId: instanceId)
    logger.info("Full sync completed for instance: \(instanceId)")
  }

  func syncLibraries(instanceId: String) async {
    do {
      let libraries: [Library] = try await api.request(path: "/api/v1/libraries")
      let libraryInfos = libraries.map { LibraryInfo(id: $0.id, name: $0.name) }
      try KomgaLibraryStore.shared.replaceLibraries(libraryInfos, for: instanceId)
      logger.info("Synced \(libraries.count) libraries")
    } catch {
      logger.error("Failed to sync libraries: \(error)")
    }
  }

  func syncCollections(instanceId: String) async {
    guard let context = makeContext() else { return }
    do {
      var page = 0
      var hasMore = true
      while hasMore {
        let result: Page<SeriesCollection> = try await CollectionService.shared.getCollections(
          page: page, size: 500)
        for collectionDto in result.content {
          await upsertCollection(dto: collectionDto, instanceId: instanceId, context: context)
        }
        hasMore = !result.last
        page += 1
      }
      try context.save()
      logger.info("Synced collections")
    } catch {
      logger.error("Failed to sync collections: \(error)")
    }
  }

  func syncReadLists(instanceId: String) async {
    guard let context = makeContext() else { return }
    do {
      let readLists: [ReadList] = try await api.request(path: "/api/v1/readlists")
      for readListDto in readLists {
        await upsertReadList(dto: readListDto, instanceId: instanceId, context: context)
      }
      try context.save()
      logger.info("Synced readlists")
    } catch {
      logger.error("Failed to sync readlists: \(error)")
    }
  }

  func syncSeries(libraryId: String, instanceId: String) async {
    guard let context = makeContext() else { return }
    do {
      var page = 0
      var hasMore = true
      let filters = SeriesSearchFilters(libraryIds: [libraryId])
      let condition = SeriesSearch.buildCondition(filters: filters)
      let search = SeriesSearch(condition: condition)
      while hasMore {
        let result = try await SeriesService.shared.getSeriesList(
          search: search, page: page, size: 100)
        for seriesDto in result.content {
          await upsertSeries(dto: seriesDto, instanceId: instanceId, context: context)
        }
        hasMore = !result.last
        page += 1
        try context.save()
      }
      logger.info("Synced series for library \(libraryId)")
    } catch {
      logger.error("Failed to sync series for library \(libraryId): \(error)")
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
    guard let context = makeContext() else {
      throw AppErrorType.storageNotConfigured(message: "Context missing")
    }

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
    for series in result.content {
      await upsertSeries(dto: series, instanceId: instanceId, context: context)
    }
    try context.save()

    return result
  }

  func syncSeriesDetail(seriesId: String) async throws -> Series {
    guard let context = makeContext() else {
      throw AppErrorType.storageNotConfigured(message: "Context missing")
    }
    let series = try await SeriesService.shared.getOneSeries(id: seriesId)
    await upsertSeries(dto: series, instanceId: AppConfig.currentInstanceId, context: context)
    try context.save()
    return series
  }

  func syncBooks(
    seriesId: String,
    page: Int,
    size: Int,
    browseOpts: BookBrowseOptions,
    libraryIds: [String]?
  ) async throws -> Page<Book> {
    guard let context = makeContext() else {
      throw AppErrorType.storageNotConfigured(message: "Context missing")
    }
    let result = try await BookService.shared.getBooks(
      seriesId: seriesId,
      page: page,
      size: size,
      browseOpts: browseOpts,
      libraryIds: libraryIds
    )
    let instanceId = AppConfig.currentInstanceId
    for book in result.content {
      await upsertBook(dto: book, instanceId: instanceId, context: context)
    }
    try context.save()
    return result
  }

  func syncBooksList(
    search: String?,
    libraryIds: [String]?,
    browseOpts: BookBrowseOptions,
    page: Int,
    size: Int,
    sort: String?
  ) async throws -> Page<Book> {
    guard let context = makeContext() else {
      throw AppErrorType.storageNotConfigured(message: "Context missing")
    }

    let filters = BookSearchFilters(
      libraryIds: libraryIds,
      includeReadStatuses: Array(browseOpts.includeReadStatuses),
      excludeReadStatuses: Array(browseOpts.excludeReadStatuses),
      oneshot: browseOpts.oneshotFilter.effectiveBool,
      deleted: browseOpts.deletedFilter.effectiveBool
    )
    let condition = BookSearch.buildCondition(filters: filters)
    let bookSearch = BookSearch(
      condition: condition,
      fullTextSearch: search?.isEmpty == false ? search : nil
    )

    let result = try await BookService.shared.getBooksList(
      search: bookSearch,
      page: page,
      size: size,
      sort: sort
    )

    let instanceId = AppConfig.currentInstanceId
    for book in result.content {
      await upsertBook(dto: book, instanceId: instanceId, context: context)
    }
    try context.save()

    return result
  }

  func syncBook(bookId: String) async throws -> Book {
    guard let context = makeContext() else {
      throw AppErrorType.storageNotConfigured(message: "Context missing")
    }
    let book = try await BookService.shared.getBook(id: bookId)
    await upsertBook(dto: book, instanceId: AppConfig.currentInstanceId, context: context)
    try context.save()
    return book
  }

  func syncCollections(
    libraryIds: [String]?,
    page: Int,
    size: Int,
    sort: String?,
    search: String?
  ) async throws -> Page<SeriesCollection> {
    guard let context = makeContext() else {
      throw AppErrorType.storageNotConfigured(message: "Context missing")
    }
    let result = try await CollectionService.shared.getCollections(
      libraryIds: libraryIds,
      page: page,
      size: size,
      sort: sort,
      search: search
    )
    let instanceId = AppConfig.currentInstanceId
    for col in result.content {
      await upsertCollection(dto: col, instanceId: instanceId, context: context)
    }
    try context.save()
    return result
  }

  func syncCollection(id: String) async throws -> SeriesCollection {
    guard let context = makeContext() else {
      throw AppErrorType.storageNotConfigured(message: "Context missing")
    }
    let collection = try await CollectionService.shared.getCollection(id: id)
    await upsertCollection(
      dto: collection, instanceId: AppConfig.currentInstanceId, context: context)
    try context.save()
    return collection
  }

  func syncCollectionSeries(
    collectionId: String,
    page: Int,
    size: Int,
    browseOpts: CollectionSeriesBrowseOptions,
    libraryIds: [String]?
  ) async throws -> Page<Series> {
    guard let context = makeContext() else {
      throw AppErrorType.storageNotConfigured(message: "Context missing")
    }
    let result = try await CollectionService.shared.getCollectionSeries(
      collectionId: collectionId,
      page: page,
      size: size,
      browseOpts: browseOpts,
      libraryIds: libraryIds
    )
    let instanceId = AppConfig.currentInstanceId
    for series in result.content {
      await upsertSeries(dto: series, instanceId: instanceId, context: context)
    }
    try context.save()
    return result
  }

  func syncReadLists(
    libraryIds: [String]?,
    page: Int,
    size: Int,
    sort: String?,
    search: String?
  ) async throws -> Page<ReadList> {
    guard let context = makeContext() else {
      throw AppErrorType.storageNotConfigured(message: "Context missing")
    }
    let result = try await ReadListService.shared.getReadLists(
      libraryIds: libraryIds,
      page: page,
      size: size,
      sort: sort,
      search: search
    )
    let instanceId = AppConfig.currentInstanceId
    for rl in result.content {
      await upsertReadList(dto: rl, instanceId: instanceId, context: context)
    }
    try context.save()
    return result
  }

  func syncReadList(id: String) async throws -> ReadList {
    guard let context = makeContext() else {
      throw AppErrorType.storageNotConfigured(message: "Context missing")
    }
    let readList = try await ReadListService.shared.getReadList(id: id)
    await upsertReadList(dto: readList, instanceId: AppConfig.currentInstanceId, context: context)
    try context.save()
    return readList
  }

  func syncReadListBooks(
    readListId: String,
    page: Int,
    size: Int,
    browseOpts: ReadListBookBrowseOptions,
    libraryIds: [String]?
  ) async throws -> Page<Book> {
    guard let context = makeContext() else {
      throw AppErrorType.storageNotConfigured(message: "Context missing")
    }
    let result = try await ReadListService.shared.getReadListBooks(
      readListId: readListId,
      page: page,
      size: size,
      browseOpts: browseOpts,
      libraryIds: libraryIds
    )
    let instanceId = AppConfig.currentInstanceId
    for book in result.content {
      await upsertBook(dto: book, instanceId: instanceId, context: context)
    }
    try context.save()
    return result
  }

  func syncDashboard(instanceId: String) async {
    // Fetch On Deck, Recently Added, Recently Read
    // And persist the associated books/series
  }

  // MARK: - Cleanup

  /// Remove all SwiftData entities associated with a specific Komga instance.
  func clearInstanceData(instanceId: String) {
    guard let context = makeContext() else { return }

    do {
      try context.delete(model: KomgaBook.self, where: #Predicate { $0.instanceId == instanceId })
      try context.delete(model: KomgaSeries.self, where: #Predicate { $0.instanceId == instanceId })
      try context.delete(
        model: KomgaCollection.self, where: #Predicate { $0.instanceId == instanceId })
      try context.delete(
        model: KomgaReadList.self, where: #Predicate { $0.instanceId == instanceId })

      try context.save()
      logger.info("Cleared all SwiftData entities for instance: \(instanceId)")
    } catch {
      logger.error("Failed to clear instance data: \(error)")
    }
  }

  // MARK: - Upsert Helpers

  private func upsertBook(dto: Book, instanceId: String, context: ModelContext) async {
    let compositeId = "\(instanceId)_\(dto.id)"
    let descriptor = FetchDescriptor<KomgaBook>(predicate: #Predicate { $0.id == compositeId })
    let seriesCompositeId = "\(instanceId)_\(dto.seriesId)"
    let seriesDescriptor = FetchDescriptor<KomgaSeries>(
      predicate: #Predicate { $0.id == seriesCompositeId })
    let parentSeries = try? context.fetch(seriesDescriptor).first
    if let existing = try? context.fetch(descriptor).first {
      existing.name = dto.name
      existing.url = dto.url
      existing.number = dto.number
      existing.lastModified = dto.lastModified
      existing.sizeBytes = dto.sizeBytes
      existing.size = dto.size
      existing.media = dto.media
      existing.metadata = dto.metadata
      existing.readProgress = dto.readProgress
      existing.deleted = dto.deleted
      existing.oneshot = dto.oneshot
      existing.series = parentSeries
    } else {
      let newBook = KomgaBook(
        bookId: dto.id,
        seriesId: dto.seriesId,
        libraryId: dto.libraryId,
        instanceId: instanceId,
        name: dto.name,
        url: dto.url,
        number: dto.number,
        created: dto.created,
        lastModified: dto.lastModified,
        sizeBytes: dto.sizeBytes,
        size: dto.size,
        media: dto.media,
        metadata: dto.metadata,
        readProgress: dto.readProgress,
        deleted: dto.deleted,
        oneshot: dto.oneshot
      )
      newBook.series = parentSeries
      context.insert(newBook)
    }
  }

  private func upsertSeries(dto: Series, instanceId: String, context: ModelContext) async {
    let compositeId = "\(instanceId)_\(dto.id)"
    let descriptor = FetchDescriptor<KomgaSeries>(predicate: #Predicate { $0.id == compositeId })
    if let existing = try? context.fetch(descriptor).first {
      existing.name = dto.name
      existing.url = dto.url
      existing.lastModified = dto.lastModified
      existing.booksCount = dto.booksCount
      existing.booksReadCount = dto.booksReadCount
      existing.booksUnreadCount = dto.booksUnreadCount
      existing.booksInProgressCount = dto.booksInProgressCount
      existing.metadata = dto.metadata
      existing.booksMetadata = dto.booksMetadata
      existing.deleted = dto.deleted
      existing.oneshot = dto.oneshot
    } else {
      let newSeries = KomgaSeries(
        seriesId: dto.id,
        libraryId: dto.libraryId,
        instanceId: instanceId,
        name: dto.name,
        url: dto.url,
        created: dto.created,
        lastModified: dto.lastModified,
        booksCount: dto.booksCount,
        booksReadCount: dto.booksReadCount,
        booksUnreadCount: dto.booksUnreadCount,
        booksInProgressCount: dto.booksInProgressCount,
        metadata: dto.metadata,
        booksMetadata: dto.booksMetadata,
        deleted: dto.deleted,
        oneshot: dto.oneshot
      )
      context.insert(newSeries)
    }
  }

  private func upsertCollection(dto: SeriesCollection, instanceId: String, context: ModelContext)
    async
  {
    let compositeId = "\(instanceId)_\(dto.id)"
    let descriptor = FetchDescriptor<KomgaCollection>(
      predicate: #Predicate { $0.id == compositeId })
    if let existing = try? context.fetch(descriptor).first {
      existing.name = dto.name
      existing.ordered = dto.ordered
      existing.filtered = dto.filtered
      existing.lastModifiedDate = dto.lastModifiedDate
      existing.seriesIds = dto.seriesIds
    } else {
      let newCollection = KomgaCollection(
        collectionId: dto.id,
        instanceId: instanceId,
        name: dto.name,
        ordered: dto.ordered,
        createdDate: dto.createdDate,
        lastModifiedDate: dto.lastModifiedDate,
        filtered: dto.filtered,
        seriesIds: dto.seriesIds
      )
      context.insert(newCollection)
    }
  }

  private func upsertReadList(dto: ReadList, instanceId: String, context: ModelContext) async {
    let compositeId = "\(instanceId)_\(dto.id)"
    let descriptor = FetchDescriptor<KomgaReadList>(predicate: #Predicate { $0.id == compositeId })
    if let existing = try? context.fetch(descriptor).first {
      existing.name = dto.name
      existing.summary = dto.summary
      existing.ordered = dto.ordered
      existing.filtered = dto.filtered
      existing.lastModifiedDate = dto.lastModifiedDate
      existing.bookIds = dto.bookIds
    } else {
      let newReadList = KomgaReadList(
        readListId: dto.id,
        instanceId: instanceId,
        name: dto.name,
        summary: dto.summary,
        ordered: dto.ordered,
        createdDate: dto.createdDate,
        lastModifiedDate: dto.lastModifiedDate,
        filtered: dto.filtered,
        bookIds: dto.bookIds
      )
      context.insert(newReadList)
    }
  }
}
