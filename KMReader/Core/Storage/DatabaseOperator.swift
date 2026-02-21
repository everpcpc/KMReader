//
// DatabaseOperator.swift
//
//

import Dependencies
import Foundation
import OSLog
import SQLiteData

struct InstanceSummary: Sendable {
  let id: UUID
  let displayName: String
}

struct PendingProgressSummary: Sendable {
  let id: String
  let instanceId: String
  let bookId: String
  let page: Int
  let completed: Bool
  let createdAt: Date
  let progressionData: Data?
}

struct DownloadQueueSummary: Sendable {
  let downloadingCount: Int
  let pendingCount: Int
  let failedCount: Int

  static let empty = DownloadQueueSummary(downloadingCount: 0, pendingCount: 0, failedCount: 0)

  var isEmpty: Bool {
    return downloadingCount == 0 && pendingCount == 0 && failedCount == 0
  }
}

actor DatabaseOperator {
  @MainActor static var shared: DatabaseOperator!

  private let logger = AppLogger(.database)

  init() {}

  private func read<T>(_ block: (Database) throws -> T) throws -> T {
    @Dependency(\.defaultDatabase) var database
    return try database.read(block)
  }

  private func write<T>(_ block: (Database) throws -> T) throws -> T {
    @Dependency(\.defaultDatabase) var database
    return try database.write(block)
  }

  // MARK: - Book Operations

  func upsertBook(dto: Book, instanceId: String) {
    do {
      try write { db in
        if var existing =
          try KomgaBookRecord
          .where({ $0.instanceId.eq(instanceId) && $0.bookId.eq(dto.id) })
          .fetchOne(db)
        {
          applyBook(dto: dto, to: &existing)
          try upsertBookRecord(existing, in: db)
        } else {
          let newBook = KomgaBookRecord(
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
            oneshot: dto.oneshot,
            seriesTitle: dto.seriesTitle
          )
          try upsertBookRecord(newBook, in: db)
        }
      }
    } catch {
      logger.error("Failed to upsert book \(dto.id): \(error.localizedDescription)")
    }
  }

  func deleteBook(id: String, instanceId: String) {
    do {
      try write { db in
        try KomgaBookRecord
          .where { $0.instanceId.eq(instanceId) && $0.bookId.eq(id) }
          .delete()
          .execute(db)
        try KomgaBookLocalStateRecord
          .where { $0.instanceId.eq(instanceId) && $0.bookId.eq(id) }
          .delete()
          .execute(db)
      }
    } catch {
      logger.error("Failed to delete book \(id): \(error.localizedDescription)")
    }
  }

  func upsertBooks(_ books: [Book], instanceId: String) {
    guard !books.isEmpty else { return }

    do {
      try write { db in
        let bookIds = books.map(\.id)
        let existingBooks =
          try KomgaBookRecord
          .where { $0.instanceId.eq(instanceId) && $0.bookId.in(bookIds) }
          .fetchAll(db)
        let existingById = Dictionary(
          existingBooks.map { ($0.bookId, $0) },
          uniquingKeysWith: { first, _ in first }
        )

        for book in books {
          if var existing = existingById[book.id] {
            applyBook(dto: book, to: &existing)
            try upsertBookRecord(existing, in: db)
          } else {
            let newBook = KomgaBookRecord(
              bookId: book.id,
              seriesId: book.seriesId,
              libraryId: book.libraryId,
              instanceId: instanceId,
              name: book.name,
              url: book.url,
              number: book.number,
              created: book.created,
              lastModified: book.lastModified,
              sizeBytes: book.sizeBytes,
              size: book.size,
              media: book.media,
              metadata: book.metadata,
              readProgress: book.readProgress,
              deleted: book.deleted,
              oneshot: book.oneshot,
              seriesTitle: book.seriesTitle
            )
            try upsertBookRecord(newBook, in: db)
          }
        }
      }
    } catch {
      logger.error("Failed to upsert books batch: \(error.localizedDescription)")
    }
  }

  func fetchBook(id: String) async -> Book? {
    KomgaBookStore.fetchBook(id: id)
  }

  func getNextBook(instanceId: String, bookId: String, readListId: String?) async -> Book? {
    if let readListId = readListId {
      let books = KomgaBookStore.fetchReadListBooks(
        readListId: readListId, page: 0, size: 1000,
        browseOpts: ReadListBookBrowseOptions())
      if let currentIndex = books.firstIndex(where: { $0.id == bookId }),
        currentIndex + 1 < books.count
      {
        return books[currentIndex + 1]
      }
    } else if let currentBook = await fetchBook(id: bookId) {
      let seriesBooks = KomgaBookStore.fetchSeriesBooks(
        seriesId: currentBook.seriesId, page: 0, size: 1000,
        browseOpts: BookBrowseOptions())
      if let currentIndex = seriesBooks.firstIndex(where: { $0.id == bookId }),
        currentIndex + 1 < seriesBooks.count
      {
        return seriesBooks[currentIndex + 1]
      }
    }
    return nil
  }

  func getPreviousBook(instanceId: String, bookId: String, readListId: String? = nil) async -> Book? {
    if let readListId = readListId {
      let books = KomgaBookStore.fetchReadListBooks(
        readListId: readListId, page: 0, size: 1000,
        browseOpts: ReadListBookBrowseOptions())
      if let currentIndex = books.firstIndex(where: { $0.id == bookId }),
        currentIndex > 0
      {
        return books[currentIndex - 1]
      }
    } else if let currentBook = await fetchBook(id: bookId) {
      let seriesBooks = KomgaBookStore.fetchSeriesBooks(
        seriesId: currentBook.seriesId, page: 0, size: 1000,
        browseOpts: BookBrowseOptions())
      if let currentIndex = seriesBooks.firstIndex(where: { $0.id == bookId }),
        currentIndex > 0
      {
        return seriesBooks[currentIndex - 1]
      }
    }
    return nil
  }

  func fetchPages(id: String) -> [BookPage]? {
    let instanceId = AppConfig.current.instanceId
    return try? read { db in
      try KomgaBookLocalStateRecord
        .where { $0.instanceId.eq(instanceId) && $0.bookId.eq(id) }
        .fetchOne(db)?
        .pages
    }
  }

  func fetchIsolatePages(id: String) -> [Int]? {
    let instanceId = AppConfig.current.instanceId
    return try? read { db in
      try KomgaBookLocalStateRecord
        .where { $0.instanceId.eq(instanceId) && $0.bookId.eq(id) }
        .fetchOne(db)?
        .isolatePages
    }
  }

  func updateIsolatePages(bookId: String, pages: [Int]) {
    let instanceId = AppConfig.current.instanceId
    do {
      try write { db in
        guard
          try KomgaBookRecord
            .where({ $0.instanceId.eq(instanceId) && $0.bookId.eq(bookId) })
            .fetchOne(db) != nil
        else { return }
        var state = try fetchOrCreateBookLocalState(instanceId: instanceId, bookId: bookId, db: db)
        state.isolatePages = pages
        try upsertBookLocalStateRecord(state, in: db)
      }
    } catch {
      logger.error("Failed to update isolate pages for book \(bookId): \(error.localizedDescription)")
    }
  }

  func fetchBookEpubPreferences(bookId: String) -> EpubReaderPreferences? {
    let instanceId = AppConfig.current.instanceId
    return try? read { db in
      try KomgaBookLocalStateRecord
        .where { $0.instanceId.eq(instanceId) && $0.bookId.eq(bookId) }
        .fetchOne(db)?
        .epubPreferences
    }
  }

  func updateBookEpubPreferences(bookId: String, preferences: EpubReaderPreferences?) {
    let instanceId = AppConfig.current.instanceId
    do {
      try write { db in
        guard
          try KomgaBookRecord
            .where({ $0.instanceId.eq(instanceId) && $0.bookId.eq(bookId) })
            .fetchOne(db) != nil
        else { return }
        var state = try fetchOrCreateBookLocalState(instanceId: instanceId, bookId: bookId, db: db)
        state.epubPreferences = preferences
        try upsertBookLocalStateRecord(state, in: db)
      }
    } catch {
      logger.error("Failed to update EPUB preferences for book \(bookId): \(error.localizedDescription)")
    }
  }

  func fetchBookEpubProgression(bookId: String) async -> R2Progression? {
    let instanceId = AppConfig.current.instanceId
    let data = try? read { db in
      try KomgaBookLocalStateRecord
        .where { $0.instanceId.eq(instanceId) && $0.bookId.eq(bookId) }
        .fetchOne(db)?
        .epubProgressionRaw
    }
    guard let data else {
      return nil
    }
    return await MainActor.run {
      let decoder = JSONDecoder()
      decoder.dateDecodingStrategy = .iso8601
      return try? decoder.decode(R2Progression.self, from: data)
    }
  }

  func updateBookEpubProgression(bookId: String, progression: R2Progression?) async {
    let instanceId = AppConfig.current.instanceId
    let progressionData: Data?
    if let progression {
      progressionData = await MainActor.run {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try? encoder.encode(progression)
      }
    } else {
      progressionData = nil
    }

    do {
      try write { db in
        guard
          try KomgaBookRecord
            .where({ $0.instanceId.eq(instanceId) && $0.bookId.eq(bookId) })
            .fetchOne(db) != nil
        else { return }
        var state = try fetchOrCreateBookLocalState(instanceId: instanceId, bookId: bookId, db: db)
        state.epubProgressionRaw = progressionData
        try upsertBookLocalStateRecord(state, in: db)
      }
    } catch {
      logger.error("Failed to update EPUB progression for book \(bookId): \(error.localizedDescription)")
    }
  }

  func fetchTOC(id: String) -> [ReaderTOCEntry]? {
    let instanceId = AppConfig.current.instanceId
    return try? read { db in
      try KomgaBookLocalStateRecord
        .where { $0.instanceId.eq(instanceId) && $0.bookId.eq(id) }
        .fetchOne(db)?
        .tableOfContents
    }
  }

  func updateBookPages(bookId: String, pages: [BookPage]) {
    let instanceId = AppConfig.current.instanceId
    do {
      try write { db in
        guard
          try KomgaBookRecord
            .where({ $0.instanceId.eq(instanceId) && $0.bookId.eq(bookId) })
            .fetchOne(db) != nil
        else { return }
        var state = try fetchOrCreateBookLocalState(instanceId: instanceId, bookId: bookId, db: db)
        state.pages = pages
        try upsertBookLocalStateRecord(state, in: db)
      }
    } catch {
      logger.error("Failed to update pages for book \(bookId): \(error.localizedDescription)")
    }
  }

  func updateBookTOC(bookId: String, toc: [ReaderTOCEntry]) {
    let instanceId = AppConfig.current.instanceId
    do {
      try write { db in
        guard
          try KomgaBookRecord
            .where({ $0.instanceId.eq(instanceId) && $0.bookId.eq(bookId) })
            .fetchOne(db) != nil
        else { return }
        var state = try fetchOrCreateBookLocalState(instanceId: instanceId, bookId: bookId, db: db)
        state.tableOfContents = toc
        try upsertBookLocalStateRecord(state, in: db)
      }
    } catch {
      logger.error("Failed to update TOC for book \(bookId): \(error.localizedDescription)")
    }
  }

  func updateBookWebPubManifest(bookId: String, manifest: WebPubPublication) async {
    let instanceId = AppConfig.current.instanceId
    let data = await MainActor.run { try? JSONEncoder().encode(manifest) }
    do {
      try write { db in
        guard
          try KomgaBookRecord
            .where({ $0.instanceId.eq(instanceId) && $0.bookId.eq(bookId) })
            .fetchOne(db) != nil
        else { return }
        var state = try fetchOrCreateBookLocalState(instanceId: instanceId, bookId: bookId, db: db)
        state.webPubManifestRaw = data
        try upsertBookLocalStateRecord(state, in: db)
      }
    } catch {
      logger.error("Failed to update WebPub manifest for book \(bookId): \(error.localizedDescription)")
    }
  }

  func fetchWebPubManifest(bookId: String) async -> WebPubPublication? {
    let instanceId = AppConfig.current.instanceId
    let data = try? read { db in
      try KomgaBookLocalStateRecord
        .where { $0.instanceId.eq(instanceId) && $0.bookId.eq(bookId) }
        .fetchOne(db)?
        .webPubManifestRaw
    }
    guard let data else {
      return nil
    }
    return await MainActor.run { try? JSONDecoder().decode(WebPubPublication.self, from: data) }
  }

  // MARK: - Series Operations

  func upsertSeries(dto: Series, instanceId: String) {
    do {
      try write { db in
        if var existing =
          try KomgaSeriesRecord
          .where({ $0.instanceId.eq(instanceId) && $0.seriesId.eq(dto.id) })
          .fetchOne(db)
        {
          applySeries(dto: dto, to: &existing)
          try upsertSeriesRecord(existing, in: db)
        } else {
          let newSeries = KomgaSeriesRecord(
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
          try upsertSeriesRecord(newSeries, in: db)
        }
      }
    } catch {
      logger.error("Failed to upsert series \(dto.id): \(error.localizedDescription)")
    }
  }

  func deleteSeries(id: String, instanceId: String) {
    do {
      try write { db in
        try KomgaSeriesRecord
          .where { $0.instanceId.eq(instanceId) && $0.seriesId.eq(id) }
          .delete()
          .execute(db)
        try KomgaSeriesLocalStateRecord
          .where { $0.instanceId.eq(instanceId) && $0.seriesId.eq(id) }
          .delete()
          .execute(db)
      }
    } catch {
      logger.error("Failed to delete series \(id): \(error.localizedDescription)")
    }
  }

  func upsertSeriesList(_ seriesList: [Series], instanceId: String) {
    guard !seriesList.isEmpty else { return }

    do {
      try write { db in
        let seriesIds = seriesList.map(\.id)
        let existingSeries =
          try KomgaSeriesRecord
          .where { $0.instanceId.eq(instanceId) && $0.seriesId.in(seriesIds) }
          .fetchAll(db)
        let existingById = Dictionary(
          existingSeries.map { ($0.seriesId, $0) },
          uniquingKeysWith: { first, _ in first }
        )

        for series in seriesList {
          if var existing = existingById[series.id] {
            applySeries(dto: series, to: &existing)
            try upsertSeriesRecord(existing, in: db)
          } else {
            let newSeries = KomgaSeriesRecord(
              seriesId: series.id,
              libraryId: series.libraryId,
              instanceId: instanceId,
              name: series.name,
              url: series.url,
              created: series.created,
              lastModified: series.lastModified,
              booksCount: series.booksCount,
              booksReadCount: series.booksReadCount,
              booksUnreadCount: series.booksUnreadCount,
              booksInProgressCount: series.booksInProgressCount,
              metadata: series.metadata,
              booksMetadata: series.booksMetadata,
              deleted: series.deleted,
              oneshot: series.oneshot
            )
            try upsertSeriesRecord(newSeries, in: db)
          }
        }
      }
    } catch {
      logger.error("Failed to upsert series list: \(error.localizedDescription)")
    }
  }

  func fetchSeries(id: String) async -> Series? {
    KomgaSeriesStore.fetchOne(seriesId: id)
  }

  func updateSeriesCollectionIds(seriesId: String, collectionIds: [String], instanceId: String) {
    do {
      try write { db in
        guard
          try KomgaSeriesRecord
            .where({ $0.instanceId.eq(instanceId) && $0.seriesId.eq(seriesId) })
            .fetchOne(db) != nil
        else { return }
        var state = try fetchOrCreateSeriesLocalState(seriesId: seriesId, instanceId: instanceId, db: db)
        guard state.collectionIds != collectionIds else { return }
        state.collectionIds = collectionIds
        try upsertSeriesLocalStateRecord(state, in: db)
      }
    } catch {
      logger.error("Failed to update series collection ids for \(seriesId): \(error.localizedDescription)")
    }
  }

  func updateBookReadListIds(bookId: String, readListIds: [String], instanceId: String) {
    do {
      try write { db in
        guard
          try KomgaBookRecord
            .where({ $0.instanceId.eq(instanceId) && $0.bookId.eq(bookId) })
            .fetchOne(db) != nil
        else { return }
        var state = try fetchOrCreateBookLocalState(instanceId: instanceId, bookId: bookId, db: db)
        guard state.readListIds != readListIds else { return }
        state.readListIds = readListIds
        try upsertBookLocalStateRecord(state, in: db)
      }
    } catch {
      logger.error("Failed to update book read list ids for \(bookId): \(error.localizedDescription)")
    }
  }

  // MARK: - Collection Operations

  func upsertCollection(dto: SeriesCollection, instanceId: String) {
    do {
      try write { db in
        if var existing =
          try KomgaCollectionRecord
          .where({ $0.instanceId.eq(instanceId) && $0.collectionId.eq(dto.id) })
          .fetchOne(db)
        {
          applyCollection(dto: dto, to: &existing)
          try upsertCollectionRecord(existing, in: db)
        } else {
          let newCollection = KomgaCollectionRecord(
            collectionId: dto.id,
            instanceId: instanceId,
            name: dto.name,
            ordered: dto.ordered,
            createdDate: dto.createdDate,
            lastModifiedDate: dto.lastModifiedDate,
            filtered: dto.filtered,
            seriesIds: dto.seriesIds
          )
          try upsertCollectionRecord(newCollection, in: db)
        }
      }
    } catch {
      logger.error("Failed to upsert collection \(dto.id): \(error.localizedDescription)")
    }
  }

  func deleteCollection(id: String, instanceId: String) {
    do {
      try write { db in
        try KomgaCollectionRecord
          .where { $0.instanceId.eq(instanceId) && $0.collectionId.eq(id) }
          .delete()
          .execute(db)
      }
    } catch {
      logger.error("Failed to delete collection \(id): \(error.localizedDescription)")
    }
  }

  func upsertCollections(_ collections: [SeriesCollection], instanceId: String) {
    guard !collections.isEmpty else { return }

    do {
      try write { db in
        let collectionIds = collections.map(\.id)
        let existingCollections =
          try KomgaCollectionRecord
          .where { $0.instanceId.eq(instanceId) && $0.collectionId.in(collectionIds) }
          .fetchAll(db)
        let existingById = Dictionary(
          existingCollections.map { ($0.collectionId, $0) },
          uniquingKeysWith: { first, _ in first }
        )

        for collection in collections {
          if var existing = existingById[collection.id] {
            applyCollection(dto: collection, to: &existing)
            try upsertCollectionRecord(existing, in: db)
          } else {
            let newCollection = KomgaCollectionRecord(
              collectionId: collection.id,
              instanceId: instanceId,
              name: collection.name,
              ordered: collection.ordered,
              createdDate: collection.createdDate,
              lastModifiedDate: collection.lastModifiedDate,
              filtered: collection.filtered,
              seriesIds: collection.seriesIds
            )
            try upsertCollectionRecord(newCollection, in: db)
          }
        }
      }
    } catch {
      logger.error("Failed to upsert collections batch: \(error.localizedDescription)")
    }
  }

  // MARK: - ReadList Operations

  func upsertReadList(dto: ReadList, instanceId: String) {
    do {
      try write { db in
        if var existing =
          try KomgaReadListRecord
          .where({ $0.instanceId.eq(instanceId) && $0.readListId.eq(dto.id) })
          .fetchOne(db)
        {
          applyReadList(dto: dto, to: &existing)
          try upsertReadListRecord(existing, in: db)
        } else {
          let newReadList = KomgaReadListRecord(
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
          try upsertReadListRecord(newReadList, in: db)
        }
      }
    } catch {
      logger.error("Failed to upsert read list \(dto.id): \(error.localizedDescription)")
    }
  }

  func deleteReadList(id: String, instanceId: String) {
    do {
      try write { db in
        try KomgaReadListRecord
          .where { $0.instanceId.eq(instanceId) && $0.readListId.eq(id) }
          .delete()
          .execute(db)
        try KomgaReadListLocalStateRecord
          .where { $0.instanceId.eq(instanceId) && $0.readListId.eq(id) }
          .delete()
          .execute(db)
      }
    } catch {
      logger.error("Failed to delete read list \(id): \(error.localizedDescription)")
    }
  }

  func upsertReadLists(_ readLists: [ReadList], instanceId: String) {
    guard !readLists.isEmpty else { return }

    do {
      try write { db in
        let readListIds = readLists.map(\.id)
        let existingReadLists =
          try KomgaReadListRecord
          .where { $0.instanceId.eq(instanceId) && $0.readListId.in(readListIds) }
          .fetchAll(db)
        let existingById = Dictionary(
          existingReadLists.map { ($0.readListId, $0) },
          uniquingKeysWith: { first, _ in first }
        )

        for readList in readLists {
          if var existing = existingById[readList.id] {
            applyReadList(dto: readList, to: &existing)
            try upsertReadListRecord(existing, in: db)
          } else {
            let newReadList = KomgaReadListRecord(
              readListId: readList.id,
              instanceId: instanceId,
              name: readList.name,
              summary: readList.summary,
              ordered: readList.ordered,
              createdDate: readList.createdDate,
              lastModifiedDate: readList.lastModifiedDate,
              filtered: readList.filtered,
              bookIds: readList.bookIds
            )
            try upsertReadListRecord(newReadList, in: db)
          }
        }
      }
    } catch {
      logger.error("Failed to upsert read lists batch: \(error.localizedDescription)")
    }
  }

  private func applyBook(dto: Book, to existing: inout KomgaBookRecord) {
    if existing.name != dto.name { existing.name = dto.name }
    if existing.url != dto.url { existing.url = dto.url }
    if existing.number != dto.number { existing.number = dto.number }
    if existing.created != dto.created { existing.created = dto.created }
    if existing.lastModified != dto.lastModified { existing.lastModified = dto.lastModified }
    if existing.sizeBytes != dto.sizeBytes { existing.sizeBytes = dto.sizeBytes }
    if existing.size != dto.size { existing.size = dto.size }
    existing.setMedia(dto.media)
    existing.setMetadata(dto.metadata)
    existing.setReadProgress(dto.readProgress)
    if existing.deleted != dto.deleted { existing.deleted = dto.deleted }
    if existing.oneshot != dto.oneshot { existing.oneshot = dto.oneshot }
    if existing.seriesTitle != dto.seriesTitle { existing.seriesTitle = dto.seriesTitle }
  }

  private static let allLibrariesId = "__all_libraries__"

  private struct SeriesPolicyActions {
    var needsSyncQueue = false
    var bookIdsToDelete: [String] = []
  }

  private func applySeries(dto: Series, to existing: inout KomgaSeriesRecord) {
    if existing.name != dto.name { existing.name = dto.name }
    if existing.url != dto.url { existing.url = dto.url }
    if existing.lastModified != dto.lastModified { existing.lastModified = dto.lastModified }
    if existing.booksCount != dto.booksCount { existing.booksCount = dto.booksCount }
    if existing.booksReadCount != dto.booksReadCount {
      existing.booksReadCount = dto.booksReadCount
    }
    if existing.booksUnreadCount != dto.booksUnreadCount {
      existing.booksUnreadCount = dto.booksUnreadCount
    }
    if existing.booksInProgressCount != dto.booksInProgressCount {
      existing.booksInProgressCount = dto.booksInProgressCount
    }
    existing.setMetadata(dto.metadata)
    existing.setBooksMetadata(dto.booksMetadata)
    if existing.deleted != dto.deleted { existing.deleted = dto.deleted }
    if existing.oneshot != dto.oneshot { existing.oneshot = dto.oneshot }
  }

  private func applyCollection(dto: SeriesCollection, to existing: inout KomgaCollectionRecord) {
    if existing.name != dto.name { existing.name = dto.name }
    if existing.ordered != dto.ordered { existing.ordered = dto.ordered }
    if existing.filtered != dto.filtered { existing.filtered = dto.filtered }
    if existing.lastModifiedDate != dto.lastModifiedDate {
      existing.lastModifiedDate = dto.lastModifiedDate
    }
    if existing.seriesIds != dto.seriesIds { existing.seriesIds = dto.seriesIds }
  }

  private func applyReadList(dto: ReadList, to existing: inout KomgaReadListRecord) {
    if existing.name != dto.name { existing.name = dto.name }
    if existing.summary != dto.summary { existing.summary = dto.summary }
    if existing.ordered != dto.ordered { existing.ordered = dto.ordered }
    if existing.filtered != dto.filtered { existing.filtered = dto.filtered }
    if existing.lastModifiedDate != dto.lastModifiedDate {
      existing.lastModifiedDate = dto.lastModifiedDate
    }
    if existing.bookIds != dto.bookIds { existing.bookIds = dto.bookIds }
  }

  private func readingStatus(progressCompleted: Bool?, progressPage: Int?) -> Int {
    if progressCompleted == true { return 2 }
    if (progressPage ?? 0) > 0 { return 1 }
    return 0
  }

  private func updateSeriesReadingCounts(
    seriesId: String,
    instanceId: String,
    oldStatus: Int,
    newStatus: Int,
    db: Database
  ) throws {
    guard var series = try fetchSeriesRecord(seriesId: seriesId, instanceId: instanceId, db: db) else { return }

    var unread = series.booksUnreadCount
    var inProgress = series.booksInProgressCount
    var read = series.booksReadCount

    switch oldStatus {
    case 0: unread -= 1
    case 1: inProgress -= 1
    case 2: read -= 1
    default: break
    }

    switch newStatus {
    case 0: unread += 1
    case 1: inProgress += 1
    case 2: read += 1
    default: break
    }

    if unread < 0 || inProgress < 0 || read < 0 || (unread + inProgress + read) > series.booksCount {
      try syncSeriesReadingStatus(seriesId: seriesId, instanceId: instanceId, db: db)
      return
    }

    series.booksUnreadCount = max(0, unread)
    series.booksInProgressCount = max(0, inProgress)
    series.booksReadCount = max(0, read)
    try upsertSeriesRecord(series, in: db)
  }

  private func applySeriesDownloadDelta(
    state: inout KomgaSeriesLocalStateRecord,
    totalBooks: Int,
    oldStatusRaw: String,
    newStatusRaw: String,
    oldDownloadedSize: Int64,
    newDownloadedSize: Int64,
    oldDownloadAt: Date?,
    newDownloadAt: Date?
  ) -> Bool {
    let wasDownloaded = oldStatusRaw == "downloaded"
    let isDownloaded = newStatusRaw == "downloaded"
    let wasPending = oldStatusRaw == "pending"
    let isPending = newStatusRaw == "pending"

    var downloadedCount = state.downloadedBooks
    var pendingCount = state.pendingBooks
    var downloadedSize = state.downloadedSize

    if wasDownloaded && !isDownloaded {
      downloadedCount -= 1
      downloadedSize -= oldDownloadedSize
    } else if !wasDownloaded && isDownloaded {
      downloadedCount += 1
      downloadedSize += newDownloadedSize
    } else if wasDownloaded && isDownloaded && oldDownloadedSize != newDownloadedSize {
      downloadedSize += (newDownloadedSize - oldDownloadedSize)
    }

    if wasPending && !isPending {
      pendingCount -= 1
    } else if !wasPending && isPending {
      pendingCount += 1
    }

    if downloadedCount < 0 || pendingCount < 0
      || downloadedCount > totalBooks
      || pendingCount > totalBooks
    {
      return true
    }

    if let oldDownloadAt, oldDownloadAt == state.downloadAt {
      if newDownloadAt == nil || (newDownloadAt ?? oldDownloadAt) < oldDownloadAt {
        return true
      }
    }

    state.downloadedBooks = max(0, downloadedCount)
    state.pendingBooks = max(0, pendingCount)
    state.downloadedSize = max(0, downloadedSize)

    if let newDownloadAt, state.downloadAt == nil || newDownloadAt > state.downloadAt! {
      state.downloadAt = newDownloadAt
    }

    if downloadedCount == totalBooks {
      state.downloadStatusRaw = "downloaded"
    } else if pendingCount > 0 {
      state.downloadStatusRaw = "pending"
    } else {
      state.downloadStatusRaw = "notDownloaded"
    }

    return false
  }

  private func applyReadListDownloadDelta(
    state: inout KomgaReadListLocalStateRecord,
    totalBooks: Int,
    oldStatusRaw: String,
    newStatusRaw: String,
    oldDownloadedSize: Int64,
    newDownloadedSize: Int64,
    oldDownloadAt: Date?,
    newDownloadAt: Date?
  ) -> Bool {
    let wasDownloaded = oldStatusRaw == "downloaded"
    let isDownloaded = newStatusRaw == "downloaded"
    let wasPending = oldStatusRaw == "pending"
    let isPending = newStatusRaw == "pending"

    var downloadedCount = state.downloadedBooks
    var pendingCount = state.pendingBooks
    var downloadedSize = state.downloadedSize

    if wasDownloaded && !isDownloaded {
      downloadedCount -= 1
      downloadedSize -= oldDownloadedSize
    } else if !wasDownloaded && isDownloaded {
      downloadedCount += 1
      downloadedSize += newDownloadedSize
    } else if wasDownloaded && isDownloaded && oldDownloadedSize != newDownloadedSize {
      downloadedSize += (newDownloadedSize - oldDownloadedSize)
    }

    if wasPending && !isPending {
      pendingCount -= 1
    } else if !wasPending && isPending {
      pendingCount += 1
    }

    if downloadedCount < 0 || pendingCount < 0
      || downloadedCount > totalBooks
      || pendingCount > totalBooks
    {
      return true
    }

    if let oldDownloadAt, oldDownloadAt == state.downloadAt {
      if !isDownloaded || newDownloadAt == nil || (newDownloadAt ?? oldDownloadAt) < oldDownloadAt {
        return true
      }
    }

    state.downloadedBooks = max(0, downloadedCount)
    state.pendingBooks = max(0, pendingCount)
    state.downloadedSize = max(0, downloadedSize)

    if isDownloaded, let newDownloadAt {
      if state.downloadAt == nil || newDownloadAt > state.downloadAt! {
        state.downloadAt = newDownloadAt
      }
    } else if downloadedCount == 0 {
      state.downloadAt = nil
    }

    if downloadedCount == totalBooks && totalBooks > 0 {
      state.downloadStatusRaw = "downloaded"
    } else if pendingCount > 0 {
      state.downloadStatusRaw = "pending"
    } else if downloadedCount > 0 {
      state.downloadStatusRaw = "partiallyDownloaded"
    } else {
      state.downloadStatusRaw = "notDownloaded"
    }

    return false
  }

  private func fetchSeriesRecord(seriesId: String, instanceId: String, db: Database) throws -> KomgaSeriesRecord? {
    try KomgaSeriesRecord
      .where { $0.instanceId.eq(instanceId) && $0.seriesId.eq(seriesId) }
      .fetchOne(db)
  }

  private func fetchReadListRecord(readListId: String, instanceId: String, db: Database) throws -> KomgaReadListRecord?
  {
    try KomgaReadListRecord
      .where { $0.instanceId.eq(instanceId) && $0.readListId.eq(readListId) }
      .fetchOne(db)
  }

  private func fetchBooksForSeries(seriesId: String, instanceId: String, db: Database) throws -> [KomgaBookRecord] {
    try KomgaBookRecord
      .where { $0.seriesId.eq(seriesId) && $0.instanceId.eq(instanceId) }
      .fetchAll(db)
  }

  private func fetchBooksByIds(
    _ bookIds: [String],
    instanceId: String,
    db: Database
  ) throws -> [KomgaBookRecord] {
    guard !bookIds.isEmpty else { return [] }

    let records =
      try KomgaBookRecord
      .where { $0.instanceId.eq(instanceId) && $0.bookId.in(bookIds) }
      .fetchAll(db)

    let order = Dictionary(uniqueKeysWithValues: bookIds.enumerated().map { ($0.element, $0.offset) })
    return records.sorted { lhs, rhs in
      (order[lhs.bookId] ?? Int.max) < (order[rhs.bookId] ?? Int.max)
    }
  }

  private func fetchBookLocalStateMap(
    books: [KomgaBookRecord],
    db: Database
  ) throws -> [String: KomgaBookLocalStateRecord] {
    guard !books.isEmpty else { return [:] }

    var stateMap: [String: KomgaBookLocalStateRecord] = [:]
    let grouped = Dictionary(grouping: books, by: \.instanceId)
    for (instanceId, groupedBooks) in grouped {
      let bookIds = Array(Set(groupedBooks.map(\.bookId)))
      guard !bookIds.isEmpty else { continue }
      let states =
        try KomgaBookLocalStateRecord
        .where { $0.instanceId.eq(instanceId) && $0.bookId.in(bookIds) }
        .fetchAll(db)
      for state in states {
        stateMap[state.bookId] = state
      }
    }
    return stateMap
  }

  private func recomputeSeriesDownloadStatus(
    seriesId: String,
    instanceId: String,
    db: Database
  ) throws -> KomgaSeriesRecord? {
    guard let series = try fetchSeriesRecord(seriesId: seriesId, instanceId: instanceId, db: db) else {
      return nil
    }

    var state = try fetchOrCreateSeriesLocalState(
      seriesId: series.seriesId,
      instanceId: series.instanceId,
      db: db
    )
    let books = try fetchBooksForSeries(seriesId: seriesId, instanceId: instanceId, db: db)
    let stateMap = try fetchBookLocalStateMap(books: books, db: db)
    let totalCount = series.booksCount
    let localStates = books.map { stateMap[$0.bookId] ?? .empty(instanceId: $0.instanceId, bookId: $0.bookId) }
    let downloadedCount = localStates.filter { $0.downloadStatusRaw == "downloaded" }.count
    let pendingCount = localStates.filter { $0.downloadStatusRaw == "pending" }.count

    state.downloadedBooks = downloadedCount
    state.pendingBooks = pendingCount
    state.downloadedSize = localStates.reduce(0) { $0 + $1.downloadedSize }
    state.downloadAt = localStates.compactMap(\.downloadAt).max()

    if downloadedCount == totalCount {
      state.downloadStatusRaw = "downloaded"
    } else if pendingCount > 0 {
      state.downloadStatusRaw = "pending"
    } else {
      state.downloadStatusRaw = "notDownloaded"
    }

    try upsertSeriesLocalStateRecord(state, in: db)
    return series
  }

  private func handleSeriesPolicyActions(
    series: KomgaSeriesRecord,
    db: Database
  ) throws -> SeriesPolicyActions {
    let state = try fetchOrCreateSeriesLocalState(
      seriesId: series.seriesId,
      instanceId: series.instanceId,
      db: db
    )
    let policy = state.offlinePolicy
    guard policy != .manual else { return SeriesPolicyActions() }

    var actions = SeriesPolicyActions()
    let books = try fetchBooksForSeries(seriesId: series.seriesId, instanceId: series.instanceId, db: db)
    let sortedBooks = books.sorted { $0.metaNumberSort < $1.metaNumberSort }
    let stateMap = try fetchBookLocalStateMap(books: sortedBooks, db: db)
    let policyLimit = max(0, state.offlinePolicyLimit)
    let policySupportsLimit = policy == .unreadOnly || policy == .unreadOnlyAndCleanupRead

    var allowedUnreadIds = Set<String>()
    if policyLimit > 0, policySupportsLimit {
      let unreadBooks = sortedBooks.filter { $0.progressCompleted != true }
      allowedUnreadIds = Set(unreadBooks.prefix(policyLimit).map(\.bookId))
    }

    let now = Date.now
    var updatedStates: [KomgaBookLocalStateRecord] = []

    for (index, book) in sortedBooks.enumerated() {
      let originalState = stateMap[book.bookId] ?? .empty(instanceId: book.instanceId, bookId: book.bookId)
      var bookState = originalState
      let isRead = book.progressCompleted ?? false
      let isDownloaded = bookState.downloadStatusRaw == "downloaded"
      let isPending = bookState.downloadStatusRaw == "pending"
      let isFailed = bookState.downloadStatusRaw == "failed"

      var shouldBeOffline: Bool
      switch policy {
      case .manual:
        shouldBeOffline = isDownloaded || isPending
      case .unreadOnly, .unreadOnlyAndCleanupRead:
        if isRead {
          shouldBeOffline = false
        } else if policyLimit > 0 {
          shouldBeOffline = allowedUnreadIds.contains(book.bookId)
        } else {
          shouldBeOffline = true
        }
      case .all:
        shouldBeOffline = true
      }

      if AppConfig.offlineAutoDeleteRead && isRead {
        if let downloadAt = bookState.downloadAt, now.timeIntervalSince(downloadAt) < 300 {
          // Keep recently downloaded for at least 5 minutes.
        } else {
          shouldBeOffline = false
        }
      }

      if shouldBeOffline {
        if !isDownloaded && !isPending && !isFailed {
          bookState.downloadStatusRaw = "pending"
          bookState.downloadAt = now.addingTimeInterval(Double(index) * 0.001)
          actions.needsSyncQueue = true
        }
      } else if (isDownloaded || isPending) && policy == .unreadOnlyAndCleanupRead && isRead {
        if let downloadAt = bookState.downloadAt, now.timeIntervalSince(downloadAt) < 300 {
          // Keep recently downloaded.
        } else if !shouldKeepBookDueToOtherPolicies(book: book, excludeSeriesId: series.seriesId, db: db) {
          bookState.downloadStatusRaw = "notDownloaded"
          bookState.downloadError = nil
          bookState.downloadAt = nil
          bookState.downloadedSize = 0
          actions.bookIdsToDelete.append(book.bookId)
        }
      }

      if bookState != originalState {
        updatedStates.append(bookState)
      }
    }

    for updated in updatedStates {
      try upsertBookLocalStateRecord(updated, in: db)
    }

    if !updatedStates.isEmpty {
      _ = try recomputeSeriesDownloadStatus(seriesId: series.seriesId, instanceId: series.instanceId, db: db)
    }

    return actions
  }

  private func syncSeriesDownloadStatus(
    seriesId: String,
    instanceId: String,
    db: Database
  ) throws -> SeriesPolicyActions {
    guard let series = try recomputeSeriesDownloadStatus(seriesId: seriesId, instanceId: instanceId, db: db) else {
      return SeriesPolicyActions()
    }
    return try handleSeriesPolicyActions(series: series, db: db)
  }

  private func recomputeReadListDownloadStatus(
    readListId: String,
    instanceId: String,
    db: Database
  ) throws -> KomgaReadListRecord? {
    guard let readList = try fetchReadListRecord(readListId: readListId, instanceId: instanceId, db: db) else {
      return nil
    }

    var state = try fetchOrCreateReadListLocalState(
      readListId: readList.readListId,
      instanceId: readList.instanceId,
      db: db
    )
    let bookIds = readList.bookIds
    guard !bookIds.isEmpty else {
      state.downloadedBooks = 0
      state.pendingBooks = 0
      state.downloadedSize = 0
      state.downloadAt = nil
      state.downloadStatusRaw = "notDownloaded"
      try upsertReadListLocalStateRecord(state, in: db)
      return readList
    }

    let books =
      try KomgaBookRecord
      .where { $0.instanceId.eq(instanceId) && $0.bookId.in(bookIds) }
      .fetchAll(db)
    let stateMap = try fetchBookLocalStateMap(books: books, db: db)

    var downloadedCount = 0
    var pendingCount = 0
    var totalSize: Int64 = 0
    var latestDownloadAt: Date?

    for book in books {
      let localState = stateMap[book.bookId] ?? .empty(instanceId: book.instanceId, bookId: book.bookId)
      if localState.downloadStatusRaw == "downloaded" {
        downloadedCount += 1
        totalSize += localState.downloadedSize
        if let downloadAt = localState.downloadAt, latestDownloadAt == nil || downloadAt > latestDownloadAt! {
          latestDownloadAt = downloadAt
        }
      } else if localState.downloadStatusRaw == "pending" {
        pendingCount += 1
      }
    }

    state.downloadedBooks = downloadedCount
    state.pendingBooks = pendingCount
    state.downloadedSize = totalSize
    state.downloadAt = latestDownloadAt

    let totalCount = bookIds.count
    if downloadedCount == totalCount && totalCount > 0 {
      state.downloadStatusRaw = "downloaded"
    } else if pendingCount > 0 {
      state.downloadStatusRaw = "pending"
    } else if downloadedCount > 0 {
      state.downloadStatusRaw = "partiallyDownloaded"
    } else {
      state.downloadStatusRaw = "notDownloaded"
    }

    try upsertReadListLocalStateRecord(state, in: db)
    return readList
  }

  private func shouldKeepBookDueToOtherPolicies(
    book: KomgaBookRecord,
    excludeSeriesId: String? = nil,
    db: Database
  ) -> Bool {
    let instanceId = book.instanceId
    if book.seriesId != excludeSeriesId,
      let series = (try? fetchSeriesRecord(seriesId: book.seriesId, instanceId: instanceId, db: db)) ?? nil
    {
      let state =
        (try? fetchOrCreateSeriesLocalState(
          seriesId: series.seriesId,
          instanceId: series.instanceId,
          db: db
        ))
      let policy = state?.offlinePolicy ?? .manual
      if policy == .all || policy == .unreadOnly {
        return true
      }
    }
    return false
  }

  private func syncSeriesReadingStatus(seriesId: String, instanceId: String, db: Database) throws {
    guard var series = try fetchSeriesRecord(seriesId: seriesId, instanceId: instanceId, db: db) else { return }
    let books = try fetchBooksForSeries(seriesId: seriesId, instanceId: instanceId, db: db)

    let unreadCount = books.filter { book in
      if book.progressCompleted == true { return false }
      if (book.progressPage ?? 0) > 0 { return false }
      return true
    }.count

    let inProgressCount = books.filter { book in
      if book.progressCompleted == true { return false }
      return (book.progressPage ?? 0) > 0
    }.count

    let readCount = books.filter { $0.progressCompleted == true }.count
    series.booksUnreadCount = unreadCount
    series.booksInProgressCount = inProgressCount
    series.booksReadCount = readCount
    try upsertSeriesRecord(series, in: db)
  }

  // MARK: - Cleanup

  func clearInstanceData(instanceId: String) {
    do {
      try write { db in
        try KomgaBookLocalStateRecord.where { $0.instanceId.eq(instanceId) }.delete().execute(db)
        try KomgaSeriesLocalStateRecord.where { $0.instanceId.eq(instanceId) }.delete().execute(db)
        try KomgaReadListLocalStateRecord.where { $0.instanceId.eq(instanceId) }.delete().execute(db)
        try KomgaBookRecord.where { $0.instanceId.eq(instanceId) }.delete().execute(db)
        try KomgaSeriesRecord.where { $0.instanceId.eq(instanceId) }.delete().execute(db)
        try KomgaCollectionRecord.where { $0.instanceId.eq(instanceId) }.delete().execute(db)
        try KomgaReadListRecord.where { $0.instanceId.eq(instanceId) }.delete().execute(db)
        try PendingProgressRecord.where { $0.instanceId.eq(instanceId) }.delete().execute(db)
      }
      logger.info("Cleared all local entities for instance: \(instanceId)")
    } catch {
      logger.error("Failed to clear instance data: \(error.localizedDescription)")
    }
  }

  // MARK: - Book Download Status Operations

  func updateBookDownloadStatus(
    bookId: String,
    instanceId: String,
    status: DownloadStatus,
    downloadAt: Date? = nil,
    downloadedSize: Int64? = nil,
    syncSeriesStatus: Bool = true
  ) {
    do {
      try write { db in
        guard
          let book =
            try KomgaBookRecord
            .where({ $0.instanceId.eq(instanceId) && $0.bookId.eq(bookId) })
            .fetchOne(db)
        else { return }
        var bookState = try fetchOrCreateBookLocalState(instanceId: instanceId, bookId: bookId, db: db)

        let oldStatusRaw = bookState.downloadStatusRaw
        let oldDownloadedSize = bookState.downloadedSize
        let oldDownloadAt = bookState.downloadAt

        bookState.downloadStatus = status
        if let downloadAt { bookState.downloadAt = downloadAt }
        if let downloadedSize {
          bookState.downloadedSize = downloadedSize
        } else if case .notDownloaded = status {
          bookState.downloadedSize = 0
        }

        if case .notDownloaded = status {
          bookState.pagesRaw = nil
          bookState.tocRaw = nil
          bookState.webPubManifestRaw = nil
        }

        try upsertBookLocalStateRecord(bookState, in: db)

        guard syncSeriesStatus else { return }

        if let series = try fetchSeriesRecord(seriesId: book.seriesId, instanceId: instanceId, db: db) {
          var seriesState = try fetchOrCreateSeriesLocalState(
            seriesId: series.seriesId,
            instanceId: series.instanceId,
            db: db
          )
          let newStatusRaw = bookState.downloadStatusRaw
          let newDownloadedSize = bookState.downloadedSize
          let newDownloadAt = bookState.downloadAt

          if seriesState.offlinePolicy == .manual {
            let needsRefresh = applySeriesDownloadDelta(
              state: &seriesState,
              totalBooks: series.booksCount,
              oldStatusRaw: oldStatusRaw,
              newStatusRaw: newStatusRaw,
              oldDownloadedSize: oldDownloadedSize,
              newDownloadedSize: newDownloadedSize,
              oldDownloadAt: oldDownloadAt,
              newDownloadAt: newDownloadAt
            )
            if needsRefresh {
              _ = try syncSeriesDownloadStatus(seriesId: book.seriesId, instanceId: instanceId, db: db)
            } else {
              try upsertSeriesLocalStateRecord(seriesState, in: db)
            }
          } else {
            _ = try syncSeriesDownloadStatus(seriesId: book.seriesId, instanceId: instanceId, db: db)
          }
        }

        for readListId in bookState.readListIds {
          guard let readList = try fetchReadListRecord(readListId: readListId, instanceId: instanceId, db: db),
            readList.bookIds.contains(book.bookId)
          else { continue }
          var readListState = try fetchOrCreateReadListLocalState(
            readListId: readList.readListId,
            instanceId: readList.instanceId,
            db: db
          )

          let needsRefresh = applyReadListDownloadDelta(
            state: &readListState,
            totalBooks: readList.bookIds.count,
            oldStatusRaw: oldStatusRaw,
            newStatusRaw: bookState.downloadStatusRaw,
            oldDownloadedSize: oldDownloadedSize,
            newDownloadedSize: bookState.downloadedSize,
            oldDownloadAt: oldDownloadAt,
            newDownloadAt: bookState.downloadAt
          )
          if needsRefresh {
            _ = try recomputeReadListDownloadStatus(readListId: readListId, instanceId: instanceId, db: db)
          } else {
            try upsertReadListLocalStateRecord(readListState, in: db)
          }
        }
      }
    } catch {
      logger.error("Failed to update book download status for \(bookId): \(error.localizedDescription)")
    }
  }

  func updateReadingProgress(bookId: String, page: Int, completed: Bool) {
    let instanceId = AppConfig.current.instanceId
    do {
      try write { db in
        guard
          var book =
            try KomgaBookRecord
            .where({ $0.instanceId.eq(instanceId) && $0.bookId.eq(bookId) })
            .fetchOne(db)
        else { return }

        let oldStatus = readingStatus(progressCompleted: book.progressCompleted, progressPage: book.progressPage)
        let now = Date()
        book.progressPage = page
        book.progressCompleted = completed
        book.progressReadDate = now
        if book.progressCreated == nil {
          book.progressCreated = now
        }
        book.progressLastModified = now
        try upsertBookRecord(book, in: db)

        let newStatus = readingStatus(progressCompleted: book.progressCompleted, progressPage: book.progressPage)
        if oldStatus != newStatus {
          try updateSeriesReadingCounts(
            seriesId: book.seriesId,
            instanceId: instanceId,
            oldStatus: oldStatus,
            newStatus: newStatus,
            db: db
          )
        }
      }
    } catch {
      logger.error("Failed to update reading progress for \(bookId): \(error.localizedDescription)")
    }
  }

  func updateEpubReadingProgressFromTotalProgression(
    bookId: String,
    totalProgression: Double?,
    fallbackPage: Int
  ) -> (page: Int, completed: Bool) {
    let instanceId = AppConfig.current.instanceId
    let normalized = min(max(totalProgression ?? 0, 0), 1)
    let completed = normalized >= 0.999_999
    var resolvedPage = max(0, fallbackPage)

    if let book =
      (try? read({ db in
        try KomgaBookRecord
          .where({ $0.instanceId.eq(instanceId) && $0.bookId.eq(bookId) })
          .fetchOne(db)
      })) ?? nil
    {
      let totalPages = max(0, book.mediaPagesCount)
      if totalPages > 0 {
        if completed {
          resolvedPage = totalPages - 1
        } else if normalized > 0 {
          let converted = Int((normalized * Double(totalPages)).rounded(.up)) - 1
          resolvedPage = min(max(0, converted), totalPages - 1)
        } else {
          resolvedPage = 0
        }
      }
    }

    updateReadingProgress(bookId: bookId, page: resolvedPage, completed: completed)
    return (resolvedPage, completed)
  }

  func syncSeriesDownloadStatus(seriesId: String, instanceId: String) {
    do {
      let actions = try write { db in
        try syncSeriesDownloadStatus(seriesId: seriesId, instanceId: instanceId, db: db)
      }

      if actions.needsSyncQueue {
        OfflineManager.shared.triggerSync(instanceId: instanceId)
      }

      if !actions.bookIdsToDelete.isEmpty {
        let ids = actions.bookIdsToDelete
        Task {
          for id in ids {
            await OfflineManager.shared.deleteBook(
              instanceId: instanceId, bookId: id, commit: false, syncSeriesStatus: false)
          }
          await DatabaseOperator.shared.syncSeriesDownloadStatus(seriesId: seriesId, instanceId: instanceId)
        }
      }
    } catch {
      logger.error("Failed to sync series download status for \(seriesId): \(error.localizedDescription)")
    }
  }

  func downloadSeriesOffline(seriesId: String, instanceId: String) {
    do {
      try write { db in
        guard let series = try fetchSeriesRecord(seriesId: seriesId, instanceId: instanceId, db: db) else { return }
        var state = try fetchOrCreateSeriesLocalState(
          seriesId: series.seriesId,
          instanceId: series.instanceId,
          db: db
        )
        state.offlinePolicy = .manual
        try upsertSeriesLocalStateRecord(state, in: db)

        let books = try fetchBooksForSeries(seriesId: seriesId, instanceId: instanceId, db: db)
          .sorted { $0.metaNumberSort < $1.metaNumberSort }
        let stateMap = try fetchBookLocalStateMap(books: books, db: db)
        let now = Date.now
        for (index, originalBook) in books.enumerated() {
          if AppConfig.offlineAutoDeleteRead && originalBook.progressCompleted == true {
            continue
          }
          var bookState =
            stateMap[originalBook.bookId]
            ?? .empty(instanceId: originalBook.instanceId, bookId: originalBook.bookId)
          if bookState.downloadStatusRaw != "downloaded" && bookState.downloadStatusRaw != "pending" {
            bookState.downloadStatusRaw = "pending"
            bookState.downloadAt = now.addingTimeInterval(Double(index) * 0.001)
            try upsertBookLocalStateRecord(bookState, in: db)
          }
        }

        _ = try recomputeSeriesDownloadStatus(seriesId: seriesId, instanceId: instanceId, db: db)
      }
      OfflineManager.shared.triggerSync(instanceId: instanceId)
    } catch {
      logger.error("Failed to queue series download for \(seriesId): \(error.localizedDescription)")
    }
  }

  func downloadSeriesUnreadOffline(seriesId: String, instanceId: String, limit: Int) {
    do {
      try write { db in
        guard let series = try fetchSeriesRecord(seriesId: seriesId, instanceId: instanceId, db: db) else { return }
        var state = try fetchOrCreateSeriesLocalState(
          seriesId: series.seriesId,
          instanceId: series.instanceId,
          db: db
        )
        state.offlinePolicy = .manual
        try upsertSeriesLocalStateRecord(state, in: db)

        let books = try fetchBooksForSeries(seriesId: seriesId, instanceId: instanceId, db: db)
          .sorted { $0.metaNumberSort < $1.metaNumberSort }
        let unreadBooks = books.filter { $0.progressCompleted != true }
        let stateMap = try fetchBookLocalStateMap(books: books, db: db)
        let targetBooks: [KomgaBookRecord]
        let limitValue = max(0, limit)
        if limitValue > 0 {
          targetBooks = Array(unreadBooks.prefix(limitValue))
        } else {
          targetBooks = unreadBooks
        }

        let now = Date.now
        for (index, originalBook) in targetBooks.enumerated() {
          var bookState =
            stateMap[originalBook.bookId]
            ?? .empty(instanceId: originalBook.instanceId, bookId: originalBook.bookId)
          if bookState.downloadStatusRaw != "downloaded" && bookState.downloadStatusRaw != "pending" {
            bookState.downloadStatusRaw = "pending"
            bookState.downloadAt = now.addingTimeInterval(Double(index) * 0.001)
            try upsertBookLocalStateRecord(bookState, in: db)
          }
        }

        _ = try recomputeSeriesDownloadStatus(seriesId: seriesId, instanceId: instanceId, db: db)
      }
      OfflineManager.shared.triggerSync(instanceId: instanceId)
    } catch {
      logger.error("Failed to queue unread series download for \(seriesId): \(error.localizedDescription)")
    }
  }

  func removeSeriesOffline(seriesId: String, instanceId: String) {
    var bookIdsToDelete: [String] = []
    do {
      try write { db in
        guard let series = try fetchSeriesRecord(seriesId: seriesId, instanceId: instanceId, db: db) else { return }
        var state = try fetchOrCreateSeriesLocalState(
          seriesId: series.seriesId,
          instanceId: series.instanceId,
          db: db
        )
        state.offlinePolicy = .manual
        try upsertSeriesLocalStateRecord(state, in: db)

        let books = try fetchBooksForSeries(seriesId: seriesId, instanceId: instanceId, db: db)
        let stateMap = try fetchBookLocalStateMap(books: books, db: db)
        for originalBook in books {
          var bookState =
            stateMap[originalBook.bookId]
            ?? .empty(instanceId: originalBook.instanceId, bookId: originalBook.bookId)
          bookState.downloadStatusRaw = "notDownloaded"
          bookState.downloadError = nil
          bookState.downloadAt = nil
          bookState.downloadedSize = 0
          try upsertBookLocalStateRecord(bookState, in: db)
          bookIdsToDelete.append(originalBook.bookId)
        }

        _ = try recomputeSeriesDownloadStatus(seriesId: seriesId, instanceId: instanceId, db: db)
      }
    } catch {
      logger.error("Failed to remove series offline data for \(seriesId): \(error.localizedDescription)")
      return
    }

    Task {
      for id in bookIdsToDelete {
        await OfflineManager.shared.deleteBook(
          instanceId: instanceId, bookId: id, commit: false, syncSeriesStatus: false)
      }
      await DatabaseOperator.shared.syncSeriesDownloadStatus(seriesId: seriesId, instanceId: instanceId)
    }
  }

  func removeSeriesReadOffline(seriesId: String, instanceId: String) {
    var bookIdsToDelete: [String] = []
    do {
      try write { db in
        guard let series = try fetchSeriesRecord(seriesId: seriesId, instanceId: instanceId, db: db) else { return }
        var state = try fetchOrCreateSeriesLocalState(
          seriesId: series.seriesId,
          instanceId: series.instanceId,
          db: db
        )
        state.offlinePolicy = .manual
        try upsertSeriesLocalStateRecord(state, in: db)

        let books = try fetchBooksForSeries(seriesId: seriesId, instanceId: instanceId, db: db)
        let stateMap = try fetchBookLocalStateMap(books: books, db: db)
        for originalBook in books where originalBook.progressCompleted == true {
          var bookState =
            stateMap[originalBook.bookId]
            ?? .empty(instanceId: originalBook.instanceId, bookId: originalBook.bookId)
          bookState.downloadStatusRaw = "notDownloaded"
          bookState.downloadError = nil
          bookState.downloadAt = nil
          bookState.downloadedSize = 0
          try upsertBookLocalStateRecord(bookState, in: db)
          bookIdsToDelete.append(originalBook.bookId)
        }

        _ = try recomputeSeriesDownloadStatus(seriesId: seriesId, instanceId: instanceId, db: db)
      }
    } catch {
      logger.error("Failed to remove read books offline for series \(seriesId): \(error.localizedDescription)")
      return
    }

    Task {
      for id in bookIdsToDelete {
        await OfflineManager.shared.deleteBook(
          instanceId: instanceId, bookId: id, commit: false, syncSeriesStatus: false)
      }
      await DatabaseOperator.shared.syncSeriesDownloadStatus(seriesId: seriesId, instanceId: instanceId)
    }
  }

  func toggleSeriesDownload(seriesId: String, instanceId: String) {
    let status: SeriesDownloadStatus? = try? read { db in
      guard let series = try fetchSeriesRecord(seriesId: seriesId, instanceId: instanceId, db: db) else {
        return nil
      }
      let state =
        try KomgaSeriesLocalStateRecord
        .where { $0.instanceId.eq(instanceId) && $0.seriesId.eq(seriesId) }
        .fetchOne(db)
      return (state ?? .empty(instanceId: instanceId, seriesId: seriesId)).downloadStatus(totalBooks: series.booksCount)
    }
    guard let status else { return }

    switch status {
    case .downloaded, .partiallyDownloaded, .pending:
      removeSeriesOffline(seriesId: seriesId, instanceId: instanceId)
    case .notDownloaded:
      downloadSeriesOffline(seriesId: seriesId, instanceId: instanceId)
    }
  }

  func updateSeriesOfflinePolicy(
    seriesId: String,
    instanceId: String,
    policy: SeriesOfflinePolicy,
    limit: Int? = nil,
    syncSeriesStatus: Bool = true
  ) {
    do {
      try write { db in
        guard let series = try fetchSeriesRecord(seriesId: seriesId, instanceId: instanceId, db: db) else { return }
        var state = try fetchOrCreateSeriesLocalState(
          seriesId: series.seriesId,
          instanceId: series.instanceId,
          db: db
        )
        state.offlinePolicy = policy
        if let limit {
          state.offlinePolicyLimit = max(0, limit)
        }
        try upsertSeriesLocalStateRecord(state, in: db)

        if syncSeriesStatus {
          _ = try syncSeriesDownloadStatus(seriesId: seriesId, instanceId: instanceId, db: db)
        }
      }
    } catch {
      logger.error("Failed to update series offline policy for \(seriesId): \(error.localizedDescription)")
    }
  }

  // MARK: - ReadList Download Status Operations

  func syncReadListDownloadStatus(readListId: String, instanceId: String) {
    do {
      try write { db in
        _ = try recomputeReadListDownloadStatus(readListId: readListId, instanceId: instanceId, db: db)
      }
    } catch {
      logger.error("Failed to sync read list download status for \(readListId): \(error.localizedDescription)")
    }
  }

  func syncReadListsContainingBooks(bookIds: [String], instanceId: String) {
    guard !bookIds.isEmpty else { return }
    let set = Set(bookIds)
    do {
      try write { db in
        let readLists = try KomgaReadListRecord.where { $0.instanceId.eq(instanceId) }.fetchAll(db)
        for readList in readLists where readList.bookIds.contains(where: { set.contains($0) }) {
          _ = try recomputeReadListDownloadStatus(
            readListId: readList.readListId,
            instanceId: instanceId,
            db: db
          )
        }
      }
    } catch {
      logger.error("Failed to sync read lists containing books: \(error.localizedDescription)")
    }
  }

  func downloadReadListOffline(readListId: String, instanceId: String) {
    var shouldTriggerSync = false
    do {
      try write { db in
        guard let readList = try fetchReadListRecord(readListId: readListId, instanceId: instanceId, db: db) else {
          return
        }
        let bookIds = readList.bookIds
        let books =
          try KomgaBookRecord
          .where { $0.instanceId.eq(instanceId) && $0.bookId.in(bookIds) }
          .fetchAll(db)
        let stateMap = try fetchBookLocalStateMap(books: books, db: db)

        let now = Date.now
        var affectedSeries = Set<String>()
        for (index, originalBook) in books.enumerated() {
          if AppConfig.offlineAutoDeleteRead && originalBook.progressCompleted == true {
            continue
          }
          var bookState =
            stateMap[originalBook.bookId]
            ?? .empty(instanceId: originalBook.instanceId, bookId: originalBook.bookId)
          if bookState.downloadStatusRaw != "downloaded" && bookState.downloadStatusRaw != "pending" {
            bookState.downloadStatusRaw = "pending"
            bookState.downloadAt = now.addingTimeInterval(Double(index) * 0.001)
            try upsertBookLocalStateRecord(bookState, in: db)
            affectedSeries.insert(originalBook.seriesId)
            shouldTriggerSync = true
          }
        }

        for seriesId in affectedSeries {
          _ = try recomputeSeriesDownloadStatus(seriesId: seriesId, instanceId: instanceId, db: db)
        }
        _ = try recomputeReadListDownloadStatus(readListId: readListId, instanceId: instanceId, db: db)
      }
      if shouldTriggerSync {
        OfflineManager.shared.triggerSync(instanceId: instanceId)
      }
    } catch {
      logger.error("Failed to queue read list download for \(readListId): \(error.localizedDescription)")
    }
  }

  func downloadReadListUnreadOffline(readListId: String, instanceId: String, limit: Int) {
    var shouldTriggerSync = false
    do {
      try write { db in
        guard let readList = try fetchReadListRecord(readListId: readListId, instanceId: instanceId, db: db) else {
          return
        }
        let bookIds = readList.bookIds
        let books =
          try KomgaBookRecord
          .where { $0.instanceId.eq(instanceId) && $0.bookId.in(bookIds) }
          .fetchAll(db)
          .sorted { $0.metaNumberSort < $1.metaNumberSort }
        let stateMap = try fetchBookLocalStateMap(books: books, db: db)

        let unreadBooks = books.filter { $0.progressCompleted != true }
        let targetBooks: [KomgaBookRecord]
        let limitValue = max(0, limit)
        if limitValue > 0 {
          targetBooks = Array(unreadBooks.prefix(limitValue))
        } else {
          targetBooks = unreadBooks
        }

        let now = Date.now
        var affectedSeries = Set<String>()
        for (index, originalBook) in targetBooks.enumerated() {
          var bookState =
            stateMap[originalBook.bookId]
            ?? .empty(instanceId: originalBook.instanceId, bookId: originalBook.bookId)
          if bookState.downloadStatusRaw != "downloaded" && bookState.downloadStatusRaw != "pending" {
            bookState.downloadStatusRaw = "pending"
            bookState.downloadAt = now.addingTimeInterval(Double(index) * 0.001)
            try upsertBookLocalStateRecord(bookState, in: db)
            affectedSeries.insert(originalBook.seriesId)
            shouldTriggerSync = true
          }
        }

        for seriesId in affectedSeries {
          _ = try recomputeSeriesDownloadStatus(seriesId: seriesId, instanceId: instanceId, db: db)
        }
        _ = try recomputeReadListDownloadStatus(readListId: readListId, instanceId: instanceId, db: db)
      }
      if shouldTriggerSync {
        OfflineManager.shared.triggerSync(instanceId: instanceId)
      }
    } catch {
      logger.error("Failed to queue unread read list download for \(readListId): \(error.localizedDescription)")
    }
  }

  func removeReadListOffline(readListId: String, instanceId: String) {
    var idsToDelete: [String] = []
    do {
      try write { db in
        guard let readList = try fetchReadListRecord(readListId: readListId, instanceId: instanceId, db: db) else {
          return
        }
        let books =
          try KomgaBookRecord
          .where { $0.instanceId.eq(instanceId) && $0.bookId.in(readList.bookIds) }
          .fetchAll(db)
        let stateMap = try fetchBookLocalStateMap(books: books, db: db)

        var affectedSeries = Set<String>()
        for originalBook in books {
          if shouldKeepBookDueToOtherPolicies(book: originalBook, db: db) {
            continue
          }
          var bookState =
            stateMap[originalBook.bookId]
            ?? .empty(instanceId: originalBook.instanceId, bookId: originalBook.bookId)
          bookState.downloadStatusRaw = "notDownloaded"
          bookState.downloadError = nil
          bookState.downloadAt = nil
          bookState.downloadedSize = 0
          try upsertBookLocalStateRecord(bookState, in: db)
          idsToDelete.append(originalBook.bookId)
          affectedSeries.insert(originalBook.seriesId)
        }

        for seriesId in affectedSeries {
          _ = try recomputeSeriesDownloadStatus(seriesId: seriesId, instanceId: instanceId, db: db)
        }
        _ = try recomputeReadListDownloadStatus(readListId: readListId, instanceId: instanceId, db: db)
      }
    } catch {
      logger.error("Failed to remove read list offline data for \(readListId): \(error.localizedDescription)")
      return
    }

    Task {
      for id in idsToDelete {
        await OfflineManager.shared.deleteBook(
          instanceId: instanceId, bookId: id, commit: false, syncSeriesStatus: false)
      }
      await DatabaseOperator.shared.syncReadListDownloadStatus(readListId: readListId, instanceId: instanceId)
    }
  }

  func removeReadListReadOffline(readListId: String, instanceId: String) {
    var idsToDelete: [String] = []
    do {
      try write { db in
        guard let readList = try fetchReadListRecord(readListId: readListId, instanceId: instanceId, db: db) else {
          return
        }
        let books =
          try KomgaBookRecord
          .where { $0.instanceId.eq(instanceId) && $0.bookId.in(readList.bookIds) }
          .fetchAll(db)
        let stateMap = try fetchBookLocalStateMap(books: books, db: db)

        var affectedSeries = Set<String>()
        for originalBook in books where originalBook.progressCompleted == true {
          if shouldKeepBookDueToOtherPolicies(book: originalBook, db: db) {
            continue
          }
          var bookState =
            stateMap[originalBook.bookId]
            ?? .empty(instanceId: originalBook.instanceId, bookId: originalBook.bookId)
          bookState.downloadStatusRaw = "notDownloaded"
          bookState.downloadError = nil
          bookState.downloadAt = nil
          bookState.downloadedSize = 0
          try upsertBookLocalStateRecord(bookState, in: db)
          idsToDelete.append(originalBook.bookId)
          affectedSeries.insert(originalBook.seriesId)
        }

        for seriesId in affectedSeries {
          _ = try recomputeSeriesDownloadStatus(seriesId: seriesId, instanceId: instanceId, db: db)
        }
        _ = try recomputeReadListDownloadStatus(readListId: readListId, instanceId: instanceId, db: db)
      }
    } catch {
      logger.error("Failed to remove read books for read list \(readListId): \(error.localizedDescription)")
      return
    }

    Task {
      for id in idsToDelete {
        await OfflineManager.shared.deleteBook(
          instanceId: instanceId, bookId: id, commit: false, syncSeriesStatus: false)
      }
      await DatabaseOperator.shared.syncReadListDownloadStatus(readListId: readListId, instanceId: instanceId)
    }
  }

  // MARK: - Library Operations

  func replaceLibraries(_ libraries: [LibraryInfo], for instanceId: String) throws {
    try write { db in
      let existing = try KomgaLibraryRecord.where { $0.instanceId.eq(instanceId) }.fetchAll(db)
      var existingMap = Dictionary(uniqueKeysWithValues: existing.map { ($0.libraryId, $0) })

      for library in libraries {
        if var existingLibrary = existingMap[library.id] {
          if existingLibrary.name != library.name {
            existingLibrary.name = library.name
            try upsertLibraryRecord(existingLibrary, in: db)
          }
          existingMap.removeValue(forKey: library.id)
        } else {
          let libraryRecord = KomgaLibraryRecord(
            instanceId: instanceId,
            libraryId: library.id,
            name: library.name
          )
          try upsertLibraryRecord(libraryRecord, in: db)
        }
      }

      for (_, library) in existingMap where library.libraryId != Self.allLibrariesId {
        try KomgaLibraryRecord.find(library.id).delete().execute(db)
      }
    }
  }

  func deleteLibrary(libraryId: String, instanceId: String) {
    do {
      try write { db in
        let bookIds =
          try KomgaBookRecord
          .where { $0.instanceId.eq(instanceId) && $0.libraryId.eq(libraryId) }
          .select { $0.bookId }
          .fetchAll(db)
        let seriesIds =
          try KomgaSeriesRecord
          .where { $0.instanceId.eq(instanceId) && $0.libraryId.eq(libraryId) }
          .select { $0.seriesId }
          .fetchAll(db)

        try KomgaLibraryRecord
          .where { $0.instanceId.eq(instanceId) && $0.libraryId.eq(libraryId) }
          .delete()
          .execute(db)

        if !bookIds.isEmpty {
          try KomgaBookLocalStateRecord
            .where { $0.instanceId.eq(instanceId) && $0.bookId.in(bookIds) }
            .delete()
            .execute(db)
        }
        try KomgaBookRecord
          .where { $0.instanceId.eq(instanceId) && $0.libraryId.eq(libraryId) }
          .delete()
          .execute(db)

        if !seriesIds.isEmpty {
          try KomgaSeriesLocalStateRecord
            .where { $0.instanceId.eq(instanceId) && $0.seriesId.in(seriesIds) }
            .delete()
            .execute(db)
        }
        try KomgaSeriesRecord
          .where { $0.instanceId.eq(instanceId) && $0.libraryId.eq(libraryId) }
          .delete()
          .execute(db)
      }
    } catch {
      logger.error("Failed to delete library \(libraryId): \(error.localizedDescription)")
    }
  }

  func deleteLibraries(instanceId: String?) throws {
    try write { db in
      if let instanceId {
        try KomgaLibraryRecord.where { $0.instanceId.eq(instanceId) }.delete().execute(db)
      } else {
        try KomgaLibraryRecord.delete().execute(db)
      }
    }
  }

  func upsertAllLibrariesEntry(
    instanceId: String,
    fileSize: Double?,
    booksCount: Double?,
    seriesCount: Double?,
    sidecarsCount: Double?,
    collectionsCount: Double?,
    readlistsCount: Double?
  ) throws {
    try write { db in
      if var existing = try KomgaLibraryRecord.where({ library in
        library.instanceId.eq(instanceId) && library.libraryId.eq(Self.allLibrariesId)
      }).fetchOne(db) {
        if existing.fileSize != fileSize { existing.fileSize = fileSize }
        if existing.booksCount != booksCount { existing.booksCount = booksCount }
        if existing.seriesCount != seriesCount { existing.seriesCount = seriesCount }
        if existing.sidecarsCount != sidecarsCount { existing.sidecarsCount = sidecarsCount }
        if existing.collectionsCount != collectionsCount { existing.collectionsCount = collectionsCount }
        if existing.readlistsCount != readlistsCount { existing.readlistsCount = readlistsCount }
        try upsertLibraryRecord(existing, in: db)
      } else {
        let allLibrariesEntry = KomgaLibraryRecord(
          instanceId: instanceId,
          libraryId: Self.allLibrariesId,
          name: "All Libraries",
          fileSize: fileSize,
          booksCount: booksCount,
          seriesCount: seriesCount,
          sidecarsCount: sidecarsCount,
          collectionsCount: collectionsCount,
          readlistsCount: readlistsCount
        )
        try upsertLibraryRecord(allLibrariesEntry, in: db)
      }
    }
  }

  func retryFailedBooks(instanceId: String) {
    do {
      try write { db in
        let failedStates =
          try KomgaBookLocalStateRecord
          .where { $0.instanceId.eq(instanceId) && $0.downloadStatusRaw.eq("failed") }
          .fetchAll(db)
        for var state in failedStates {
          state.downloadStatusRaw = "pending"
          state.downloadError = nil
          state.downloadAt = Date.now
          try upsertBookLocalStateRecord(state, in: db)
        }
      }
    } catch {
      logger.error("Failed to retry failed books for instance \(instanceId): \(error.localizedDescription)")
    }
  }

  func cancelFailedBooks(instanceId: String) {
    do {
      try write { db in
        let failedStates =
          try KomgaBookLocalStateRecord
          .where { $0.instanceId.eq(instanceId) && $0.downloadStatusRaw.eq("failed") }
          .fetchAll(db)
        for var state in failedStates {
          state.downloadStatusRaw = "notDownloaded"
          state.downloadError = nil
          state.downloadAt = nil
          state.downloadedSize = 0
          try upsertBookLocalStateRecord(state, in: db)
        }
      }
    } catch {
      logger.error("Failed to cancel failed books for instance \(instanceId): \(error.localizedDescription)")
    }
  }

  // MARK: - Instance Operations

  func upsertInstance(
    serverURL: String,
    username: String,
    authToken: String,
    isAdmin: Bool,
    authMethod: AuthenticationMethod = .basicAuth,
    displayName: String? = nil,
    instanceId: UUID? = nil
  ) throws -> InstanceSummary {
    let trimmedDisplayName = displayName?.trimmingCharacters(in: .whitespacesAndNewlines)

    return try write { db in
      if var existing = try KomgaInstanceRecord.where({ instance in
        instance.serverURL.eq(serverURL) && instance.username.eq(username)
      }).fetchOne(db) {
        existing.authToken = authToken
        existing.isAdmin = isAdmin
        existing.authMethod = authMethod
        existing.lastUsedAt = Date()
        if let trimmedDisplayName, !trimmedDisplayName.isEmpty {
          existing.name = trimmedDisplayName
        } else if existing.name.isEmpty {
          existing.name = Self.defaultName(serverURL: serverURL, username: username)
        }
        try upsertInstanceRecord(existing, in: db)
        return InstanceSummary(id: existing.id, displayName: existing.displayName)
      } else {
        let resolvedName = Self.resolvedName(
          displayName: trimmedDisplayName,
          serverURL: serverURL,
          username: username
        )
        let record = KomgaInstanceRecord(
          id: instanceId ?? UUID(),
          name: resolvedName,
          serverURL: serverURL,
          username: username,
          authToken: authToken,
          isAdmin: isAdmin,
          authMethod: authMethod
        )
        try upsertInstanceRecord(record, in: db)
        return InstanceSummary(id: record.id, displayName: record.displayName)
      }
    }
  }

  private static func defaultName(serverURL: String, username: String) -> String {
    if let host = URL(string: serverURL)?.host, !host.isEmpty {
      return host
    }
    return serverURL
  }

  private static func resolvedName(
    displayName: String?,
    serverURL: String,
    username: String
  ) -> String {
    if let displayName, !displayName.isEmpty {
      return displayName
    }
    return defaultName(serverURL: serverURL, username: username)
  }

  func updateInstanceLastUsed(instanceId: String) {
    guard let uuid = UUID(uuidString: instanceId) else { return }
    do {
      try write { db in
        guard var instance = try KomgaInstanceRecord.find(uuid).fetchOne(db) else { return }
        instance.lastUsedAt = Date()
        try upsertInstanceRecord(instance, in: db)
      }
    } catch {
      logger.error("Failed to update last used for instance \(instanceId): \(error.localizedDescription)")
    }
  }

  func updateSeriesLastSyncedAt(instanceId: String, date: Date) throws {
    guard let uuid = UUID(uuidString: instanceId) else { return }
    try write { db in
      guard var instance = try KomgaInstanceRecord.find(uuid).fetchOne(db) else { return }
      instance.seriesLastSyncedAt = date
      try upsertInstanceRecord(instance, in: db)
    }
  }

  func updateBooksLastSyncedAt(instanceId: String, date: Date) throws {
    guard let uuid = UUID(uuidString: instanceId) else { return }
    try write { db in
      guard var instance = try KomgaInstanceRecord.find(uuid).fetchOne(db) else { return }
      instance.booksLastSyncedAt = date
      try upsertInstanceRecord(instance, in: db)
    }
  }

  // MARK: - Fetch Operations

  func fetchInstance(idString: String?) -> KomgaInstance? {
    guard let idString, let uuid = UUID(uuidString: idString) else {
      return nil
    }
    return try? read { db in
      try KomgaInstanceRecord.find(uuid).fetchOne(db)?.toKomgaInstance()
    }
  }

  func getLastSyncedAt(instanceId: String) -> (series: Date, books: Date) {
    guard let instance = fetchInstance(idString: instanceId) else {
      return (Date(timeIntervalSince1970: 0), Date(timeIntervalSince1970: 0))
    }
    return (instance.seriesLastSyncedAt, instance.booksLastSyncedAt)
  }

  func fetchLibraries(instanceId: String) -> [LibraryInfo] {
    (try? read { db in
      let libraries =
        try KomgaLibraryRecord
        .where { $0.instanceId.eq(instanceId) }
        .fetchAll(db)
        .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
      return libraries.map { LibraryInfo(id: $0.libraryId, name: $0.name) }
    }) ?? []
  }

  // MARK: - Book Fetch Operations (for internal use, e.g., OfflineManager)

  func getDownloadStatus(bookId: String) -> DownloadStatus {
    let instanceId = AppConfig.current.instanceId
    return
      (try? read { db in
        let state =
          try KomgaBookLocalStateRecord
          .where { $0.instanceId.eq(instanceId) && $0.bookId.eq(bookId) }
          .fetchOne(db)
        return (state ?? .empty(instanceId: instanceId, bookId: bookId)).downloadStatus
      }) ?? .notDownloaded
  }

  func isBookReadCompleted(bookId: String, instanceId: String) -> Bool {
    return
      (try? read { db in
        try KomgaBookRecord
          .where({ $0.instanceId.eq(instanceId) && $0.bookId.eq(bookId) })
          .fetchOne(db)?
          .progressCompleted == true
      }) ?? false
  }

  func fetchPendingBooks(instanceId: String, limit: Int? = nil) -> [Book] {
    (try? read { db in
      let pendingStates =
        try KomgaBookLocalStateRecord
        .where { $0.instanceId.eq(instanceId) && $0.downloadStatusRaw.eq("pending") }
        .fetchAll(db)
      var pendingIds = pendingStates.sorted { lhs, rhs in
        switch (lhs.downloadAt, rhs.downloadAt) {
        case (let l?, let r?): return l < r
        case (nil, nil): return false
        case (nil, _): return false
        case (_, nil): return true
        }
      }
      .map(\.bookId)
      if let limit {
        let boundedLimit = max(0, limit)
        guard boundedLimit > 0 else { return [] }
        pendingIds = Array(pendingIds.prefix(boundedLimit))
      }
      let books = try fetchBooksByIds(pendingIds, instanceId: instanceId, db: db)
      return books.map { $0.toBook() }
    }) ?? []
  }

  func fetchDownloadQueueSummary(instanceId: String) -> DownloadQueueSummary {
    let downloadingCount = fetchBooksCount(instanceId: instanceId, status: "downloading")
    let pendingCount = fetchBooksCount(instanceId: instanceId, status: "pending")
    let failedCount = fetchBooksCount(instanceId: instanceId, status: "failed")
    return DownloadQueueSummary(
      downloadingCount: downloadingCount,
      pendingCount: pendingCount,
      failedCount: failedCount
    )
  }

  func fetchDownloadedBooksCount(instanceId: String) -> Int {
    fetchBooksCount(instanceId: instanceId, status: "downloaded")
  }

  func fetchDownloadedBooks(instanceId: String) -> [Book] {
    (try? read { db in
      let downloadedIds =
        try KomgaBookLocalStateRecord
        .where { $0.instanceId.eq(instanceId) && $0.downloadStatusRaw.eq("downloaded") }
        .select { $0.bookId }
        .fetchAll(db)
      let books = try fetchBooksByIds(downloadedIds, instanceId: instanceId, db: db)
      return books.map { $0.toBook() }
    }) ?? []
  }

  func fetchOfflineEpubBookIdsMissingProgression(instanceId: String) -> [String] {
    (try? read { db in
      let allBooks = try KomgaBookRecord.where { $0.instanceId.eq(instanceId) }.fetchAll(db)
      let stateMap = Dictionary(
        uniqueKeysWithValues:
          try fetchBookLocalStateMap(books: allBooks, db: db).map { ($0.key, $0.value) }
      )
      return allBooks.compactMap { book in
        guard
          stateMap[book.bookId]?.downloadStatusRaw == "downloaded",
          book.mediaProfile == "EPUB",
          (book.progressPage ?? 0) > 0,
          stateMap[book.bookId]?.epubProgressionRaw == nil
        else {
          return nil
        }
        return book.bookId
      }
    }) ?? []
  }

  func fetchReadBooksEligibleForAutoDelete(instanceId: String) -> [(id: String, seriesId: String)] {
    (try? read { db in
      let results = try KomgaBookRecord.where { $0.instanceId.eq(instanceId) && $0.progressCompleted.eq(true) }
        .fetchAll(db)
      let stateMap = try fetchBookLocalStateMap(books: results, db: db)
      let now = Date.now
      return results.compactMap { book in
        guard stateMap[book.bookId]?.downloadStatusRaw == "downloaded" else {
          return nil
        }
        if let downloadAt = stateMap[book.bookId]?.downloadAt, now.timeIntervalSince(downloadAt) < 300 {
          return nil
        }
        return (id: book.bookId, seriesId: book.seriesId)
      }
    }) ?? []
  }

  func fetchKeepReadingBooksForWidget(
    instanceId: String,
    libraryIds: [String],
    limit: Int
  ) -> [Book] {
    (try? read { db in
      let boundedLimit = max(0, limit)
      guard boundedLimit > 0 else { return [] }

      let hasLibraryFilter = !libraryIds.isEmpty
      let records =
        try KomgaBookRecord
        .where {
          $0.instanceId.eq(instanceId)
            && (!hasLibraryFilter || $0.libraryId.in(libraryIds))
            && $0.progressCompleted.eq(false)
        }
        .order { $0.progressReadDate.desc() }
        .limit(boundedLimit)
        .fetchAll(db)

      return
        records
        .filter { $0.progressReadDate != nil }
        .map { $0.toBook() }
    }) ?? []
  }

  func fetchRecentlyAddedBooksForWidget(
    instanceId: String,
    libraryIds: [String],
    limit: Int
  ) -> [Book] {
    (try? read { db in
      let boundedLimit = max(0, limit)
      guard boundedLimit > 0 else { return [] }

      let hasLibraryFilter = !libraryIds.isEmpty
      let records =
        try KomgaBookRecord
        .where {
          $0.instanceId.eq(instanceId)
            && (!hasLibraryFilter || $0.libraryId.in(libraryIds))
        }
        .order { $0.created.desc() }
        .limit(boundedLimit)
        .fetchAll(db)

      return records.map { $0.toBook() }
    }) ?? []
  }

  func fetchRecentlyUpdatedSeriesForWidget(
    instanceId: String,
    libraryIds: [String],
    limit: Int
  ) -> [Series] {
    (try? read { db in
      let boundedLimit = max(0, limit)
      guard boundedLimit > 0 else { return [] }

      let hasLibraryFilter = !libraryIds.isEmpty
      let records =
        try KomgaSeriesRecord
        .where {
          $0.instanceId.eq(instanceId)
            && (!hasLibraryFilter || $0.libraryId.in(libraryIds))
        }
        .order { $0.lastModified.desc() }
        .limit(boundedLimit)
        .fetchAll(db)

      return records.map { $0.toSeries() }
    }) ?? []
  }

  func fetchFailedBooksCount(instanceId: String) -> Int {
    fetchBooksCount(instanceId: instanceId, status: "failed")
  }

  private func fetchBooksCount(instanceId: String, status: String) -> Int {
    (try? read { db in
      try KomgaBookLocalStateRecord
        .where { $0.instanceId.eq(instanceId) && $0.downloadStatusRaw.eq(status) }
        .fetchCount(db)
    }) ?? 0
  }

  func syncSeriesReadingStatus(seriesId: String, instanceId: String) {
    do {
      try write { db in
        try syncSeriesReadingStatus(seriesId: seriesId, instanceId: instanceId, db: db)
      }
    } catch {
      logger.error("Failed to sync series reading status for \(seriesId): \(error.localizedDescription)")
    }
  }

  // MARK: - Pending Progress Operations

  func queuePendingProgress(
    instanceId: String,
    bookId: String,
    page: Int,
    completed: Bool,
    progressionData: Data? = nil
  ) {
    do {
      try write { db in
        if var existing =
          try PendingProgressRecord
          .where({ $0.instanceId.eq(instanceId) && $0.bookId.eq(bookId) })
          .fetchOne(db)
        {
          if existing.page != page { existing.page = page }
          if existing.completed != completed { existing.completed = completed }
          existing.createdAt = Date()
          if existing.progressionData != progressionData { existing.progressionData = progressionData }
          try upsertPendingProgressRecord(existing, in: db)
          logger.debug(
            "Updated pending progress id=\(existing.id): book=\(bookId), page=\(page), completed=\(completed), hasProgressionData=\(progressionData != nil)"
          )
        } else {
          var pending = PendingProgressRecord(
            instanceId: instanceId,
            bookId: bookId,
            page: page,
            completed: completed,
            progressionData: progressionData
          )
          pending.createdAt = Date()
          try upsertPendingProgressRecord(pending, in: db)
          logger.debug(
            "Queued pending progress id=\(pending.id): book=\(bookId), page=\(page), completed=\(completed), hasProgressionData=\(progressionData != nil)"
          )
        }
      }
    } catch {
      logger.error("Failed to queue pending progress for book \(bookId): \(error.localizedDescription)")
    }
  }

  func fetchPendingProgress(instanceId: String, limit: Int? = nil) -> [PendingProgressSummary] {
    let results: [PendingProgressRecord] =
      (try? read { db in
        if let limit {
          let boundedLimit = max(0, limit)
          guard boundedLimit > 0 else { return [] }
          return
            try PendingProgressRecord
            .where { $0.instanceId.eq(instanceId) }
            .order { $0.createdAt.asc() }
            .limit(boundedLimit)
            .fetchAll(db)
        }
        return
          try PendingProgressRecord
          .where { $0.instanceId.eq(instanceId) }
          .order { $0.createdAt.asc() }
          .fetchAll(db)
      }) ?? []

    logger.debug(
      "Fetched pending progress for instance \(instanceId): count=\(results.count), limit=\(limit?.description ?? "nil")"
    )

    return results.map {
      PendingProgressSummary(
        id: $0.id,
        instanceId: $0.instanceId,
        bookId: $0.bookId,
        page: $0.page,
        completed: $0.completed,
        createdAt: $0.createdAt,
        progressionData: $0.progressionData
      )
    }
  }

  func deletePendingProgress(id: String) {
    do {
      try write { db in
        try PendingProgressRecord.find(id).delete().execute(db)
      }
      logger.debug("Deleted pending progress id=\(id)")
    } catch {
      logger.warning("Pending progress id=\(id) delete failed: \(error.localizedDescription)")
    }
  }

  private func upsertBookRecord(_ record: KomgaBookRecord, in db: Database) throws {
    let query = KomgaBookRecord.where { $0.instanceId.eq(record.instanceId) && $0.bookId.eq(record.bookId) }

    if let existing = try query.fetchOne(db) {
      guard existing != record else { return }
      try query
        .update {
          $0.seriesId = #bind(record.seriesId)
          $0.libraryId = #bind(record.libraryId)
          $0.name = #bind(record.name)
          $0.url = #bind(record.url)
          $0.number = #bind(record.number)
          $0.created = #bind(record.created)
          $0.lastModified = #bind(record.lastModified)
          $0.sizeBytes = #bind(record.sizeBytes)
          $0.size = #bind(record.size)
          $0.seriesTitle = #bind(record.seriesTitle)
          $0.deleted = #bind(record.deleted)
          $0.oneshot = #bind(record.oneshot)
          $0.mediaRaw = #bind(record.mediaRaw)
          $0.metadataRaw = #bind(record.metadataRaw)
          $0.readProgressRaw = #bind(record.readProgressRaw)
          $0.mediaProfile = #bind(record.mediaProfile)
          $0.mediaPagesCount = #bind(record.mediaPagesCount)
          $0.metaTitle = #bind(record.metaTitle)
          $0.metaNumber = #bind(record.metaNumber)
          $0.metaNumberSort = #bind(record.metaNumberSort)
          $0.metaReleaseDate = #bind(record.metaReleaseDate)
          $0.progressPage = #bind(record.progressPage)
          $0.progressCompleted = #bind(record.progressCompleted)
          $0.progressReadDate = #bind(record.progressReadDate)
          $0.progressCreated = #bind(record.progressCreated)
          $0.progressLastModified = #bind(record.progressLastModified)
        }
        .execute(db)
    } else {
      try KomgaBookRecord.insert { record }.execute(db)
    }

    if try KomgaBookLocalStateRecord
      .where({ $0.instanceId.eq(record.instanceId) && $0.bookId.eq(record.bookId) })
      .fetchOne(db) == nil
    {
      try upsertBookLocalStateRecord(
        .empty(instanceId: record.instanceId, bookId: record.bookId),
        in: db
      )
    }
  }

  private func fetchOrCreateBookLocalState(
    instanceId: String,
    bookId: String,
    db: Database
  ) throws -> KomgaBookLocalStateRecord {
    if let state =
      try KomgaBookLocalStateRecord
      .where({ $0.instanceId.eq(instanceId) && $0.bookId.eq(bookId) })
      .fetchOne(db)
    {
      return state
    }
    let state = KomgaBookLocalStateRecord.empty(instanceId: instanceId, bookId: bookId)
    try upsertBookLocalStateRecord(state, in: db)
    return state
  }

  private func upsertBookLocalStateRecord(_ record: KomgaBookLocalStateRecord, in db: Database) throws {
    let query = KomgaBookLocalStateRecord.where {
      $0.instanceId.eq(record.instanceId) && $0.bookId.eq(record.bookId)
    }

    if let existing = try query.fetchOne(db) {
      guard existing != record else { return }
      try query
        .update {
          $0.pagesRaw = #bind(record.pagesRaw)
          $0.tocRaw = #bind(record.tocRaw)
          $0.webPubManifestRaw = #bind(record.webPubManifestRaw)
          $0.epubProgressionRaw = #bind(record.epubProgressionRaw)
          $0.isolatePagesRaw = #bind(record.isolatePagesRaw)
          $0.epubPreferencesRaw = #bind(record.epubPreferencesRaw)
          $0.downloadStatusRaw = #bind(record.downloadStatusRaw)
          $0.downloadError = #bind(record.downloadError)
          $0.downloadAt = #bind(record.downloadAt)
          $0.downloadedSize = #bind(record.downloadedSize)
          $0.readListIdsRaw = #bind(record.readListIdsRaw)
        }
        .execute(db)
      return
    }

    try KomgaBookLocalStateRecord.insert { record }.execute(db)
  }

  private func upsertSeriesRecord(_ record: KomgaSeriesRecord, in db: Database) throws {
    let query = KomgaSeriesRecord.where { $0.instanceId.eq(record.instanceId) && $0.seriesId.eq(record.seriesId) }

    if let existing = try query.fetchOne(db) {
      guard existing != record else { return }
      try query
        .update {
          $0.libraryId = #bind(record.libraryId)
          $0.name = #bind(record.name)
          $0.url = #bind(record.url)
          $0.created = #bind(record.created)
          $0.lastModified = #bind(record.lastModified)
          $0.booksCount = #bind(record.booksCount)
          $0.booksReadCount = #bind(record.booksReadCount)
          $0.booksUnreadCount = #bind(record.booksUnreadCount)
          $0.booksInProgressCount = #bind(record.booksInProgressCount)
          $0.deleted = #bind(record.deleted)
          $0.oneshot = #bind(record.oneshot)
          $0.metadataRaw = #bind(record.metadataRaw)
          $0.booksMetadataRaw = #bind(record.booksMetadataRaw)
          $0.metaStatus = #bind(record.metaStatus)
          $0.metaTitle = #bind(record.metaTitle)
          $0.metaTitleSort = #bind(record.metaTitleSort)
          $0.booksMetaReleaseDate = #bind(record.booksMetaReleaseDate)
        }
        .execute(db)
    } else {
      try KomgaSeriesRecord.insert { record }.execute(db)
    }

    if try KomgaSeriesLocalStateRecord
      .where({ $0.instanceId.eq(record.instanceId) && $0.seriesId.eq(record.seriesId) })
      .fetchOne(db) == nil
    {
      try upsertSeriesLocalStateRecord(
        .empty(instanceId: record.instanceId, seriesId: record.seriesId),
        in: db
      )
    }
  }

  private func upsertCollectionRecord(_ record: KomgaCollectionRecord, in db: Database) throws {
    let query = KomgaCollectionRecord.where {
      $0.instanceId.eq(record.instanceId) && $0.collectionId.eq(record.collectionId)
    }

    if let existing = try query.fetchOne(db) {
      guard existing != record else { return }
      try query
        .update {
          $0.name = #bind(record.name)
          $0.ordered = #bind(record.ordered)
          $0.createdDate = #bind(record.createdDate)
          $0.lastModifiedDate = #bind(record.lastModifiedDate)
          $0.filtered = #bind(record.filtered)
          $0.seriesIdsRaw = #bind(record.seriesIdsRaw)
        }
        .execute(db)
      return
    }

    try KomgaCollectionRecord.insert { record }.execute(db)
  }

  private func upsertReadListRecord(_ record: KomgaReadListRecord, in db: Database) throws {
    let query = KomgaReadListRecord.where {
      $0.instanceId.eq(record.instanceId) && $0.readListId.eq(record.readListId)
    }

    if let existing = try query.fetchOne(db) {
      guard existing != record else { return }
      try query
        .update {
          $0.name = #bind(record.name)
          $0.summary = #bind(record.summary)
          $0.ordered = #bind(record.ordered)
          $0.createdDate = #bind(record.createdDate)
          $0.lastModifiedDate = #bind(record.lastModifiedDate)
          $0.filtered = #bind(record.filtered)
          $0.bookIdsRaw = #bind(record.bookIdsRaw)
        }
        .execute(db)
    } else {
      try KomgaReadListRecord.insert { record }.execute(db)
    }

    if try KomgaReadListLocalStateRecord
      .where({ $0.instanceId.eq(record.instanceId) && $0.readListId.eq(record.readListId) })
      .fetchOne(db) == nil
    {
      try upsertReadListLocalStateRecord(
        .empty(instanceId: record.instanceId, readListId: record.readListId),
        in: db
      )
    }
  }

  private func fetchOrCreateSeriesLocalState(
    seriesId: String,
    instanceId: String,
    db: Database
  ) throws -> KomgaSeriesLocalStateRecord {
    if let state =
      try KomgaSeriesLocalStateRecord
      .where({ $0.instanceId.eq(instanceId) && $0.seriesId.eq(seriesId) })
      .fetchOne(db)
    {
      return state
    }
    let state = KomgaSeriesLocalStateRecord.empty(instanceId: instanceId, seriesId: seriesId)
    try upsertSeriesLocalStateRecord(state, in: db)
    return state
  }

  private func upsertSeriesLocalStateRecord(_ record: KomgaSeriesLocalStateRecord, in db: Database) throws {
    let query = KomgaSeriesLocalStateRecord.where {
      $0.instanceId.eq(record.instanceId) && $0.seriesId.eq(record.seriesId)
    }

    if let existing = try query.fetchOne(db) {
      guard existing != record else { return }
      try query
        .update {
          $0.downloadStatusRaw = #bind(record.downloadStatusRaw)
          $0.downloadError = #bind(record.downloadError)
          $0.downloadAt = #bind(record.downloadAt)
          $0.downloadedSize = #bind(record.downloadedSize)
          $0.downloadedBooks = #bind(record.downloadedBooks)
          $0.pendingBooks = #bind(record.pendingBooks)
          $0.offlinePolicyRaw = #bind(record.offlinePolicyRaw)
          $0.offlinePolicyLimit = #bind(record.offlinePolicyLimit)
          $0.collectionIdsRaw = #bind(record.collectionIdsRaw)
        }
        .execute(db)
      return
    }

    try KomgaSeriesLocalStateRecord.insert { record }.execute(db)
  }

  private func fetchOrCreateReadListLocalState(
    readListId: String,
    instanceId: String,
    db: Database
  ) throws -> KomgaReadListLocalStateRecord {
    if let state =
      try KomgaReadListLocalStateRecord
      .where({ $0.instanceId.eq(instanceId) && $0.readListId.eq(readListId) })
      .fetchOne(db)
    {
      return state
    }
    let state = KomgaReadListLocalStateRecord.empty(instanceId: instanceId, readListId: readListId)
    try upsertReadListLocalStateRecord(state, in: db)
    return state
  }

  private func upsertReadListLocalStateRecord(_ record: KomgaReadListLocalStateRecord, in db: Database) throws {
    let query = KomgaReadListLocalStateRecord.where {
      $0.instanceId.eq(record.instanceId) && $0.readListId.eq(record.readListId)
    }

    if let existing = try query.fetchOne(db) {
      guard existing != record else { return }
      try query
        .update {
          $0.downloadStatusRaw = #bind(record.downloadStatusRaw)
          $0.downloadError = #bind(record.downloadError)
          $0.downloadAt = #bind(record.downloadAt)
          $0.downloadedSize = #bind(record.downloadedSize)
          $0.downloadedBooks = #bind(record.downloadedBooks)
          $0.pendingBooks = #bind(record.pendingBooks)
        }
        .execute(db)
      return
    }

    try KomgaReadListLocalStateRecord.insert { record }.execute(db)
  }

  private func upsertLibraryRecord(_ record: KomgaLibraryRecord, in db: Database) throws {
    if let existing = try KomgaLibraryRecord.where({ $0.id.eq(record.id) }).fetchOne(db), existing == record {
      return
    }
    try KomgaLibraryRecord.upsert {
      KomgaLibraryRecord.Draft(
        id: record.id,
        instanceId: record.instanceId,
        libraryId: record.libraryId,
        name: record.name,
        createdAt: record.createdAt,
        fileSize: record.fileSize,
        booksCount: record.booksCount,
        seriesCount: record.seriesCount,
        sidecarsCount: record.sidecarsCount,
        collectionsCount: record.collectionsCount,
        readlistsCount: record.readlistsCount
      )
    }
    .execute(db)
  }

  private func upsertInstanceRecord(_ record: KomgaInstanceRecord, in db: Database) throws {
    if let existing = try KomgaInstanceRecord.where({ $0.id.eq(record.id) }).fetchOne(db), existing == record {
      return
    }
    try KomgaInstanceRecord.upsert {
      KomgaInstanceRecord.Draft(
        id: record.id,
        name: record.name,
        serverURL: record.serverURL,
        username: record.username,
        authToken: record.authToken,
        isAdmin: record.isAdmin,
        authMethodRaw: record.authMethodRaw,
        createdAt: record.createdAt,
        lastUsedAt: record.lastUsedAt,
        seriesLastSyncedAt: record.seriesLastSyncedAt,
        booksLastSyncedAt: record.booksLastSyncedAt
      )
    }
    .execute(db)
  }

  private func upsertPendingProgressRecord(_ record: PendingProgressRecord, in db: Database) throws {
    if let existing = try PendingProgressRecord.where({ $0.id.eq(record.id) }).fetchOne(db),
      existing == record
    {
      return
    }
    try PendingProgressRecord.upsert {
      PendingProgressRecord.Draft(
        id: record.id,
        instanceId: record.instanceId,
        bookId: record.bookId,
        page: record.page,
        completed: record.completed,
        createdAt: record.createdAt,
        progressionData: record.progressionData
      )
    }
    .execute(db)
  }
}
