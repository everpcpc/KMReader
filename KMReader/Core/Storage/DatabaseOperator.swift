//
//  DatabaseOperator.swift
//  KMReader
//
//  Created by Komga iOS Client
//

import Foundation
import OSLog
import SwiftData

@ModelActor
actor DatabaseOperator {
  static var shared: DatabaseOperator!

  private let logger = AppLogger(.database)
  private var pendingCommitTask: Task<Void, Never>?

  /// Commits changes with a 2-second debounce to avoid frequent UI updates
  func commit() {
    pendingCommitTask?.cancel()
    pendingCommitTask = Task {
      try? await Task.sleep(for: .milliseconds(500))
      guard !Task.isCancelled else { return }
      do {
        try modelContext.save()
      } catch {
        logger.error("Failed to commit: \(error)")
      }
    }
  }

  /// Commits changes immediately without debounce
  func commitImmediately() throws {
    pendingCommitTask?.cancel()
    pendingCommitTask = nil
    try modelContext.save()
  }

  func hasChanges() -> Bool {
    return modelContext.hasChanges
  }

  // MARK: - Book Operations

  func upsertBook(dto: Book, instanceId: String) {
    let compositeId = CompositeID.generate(instanceId: instanceId, id: dto.id)
    let descriptor = FetchDescriptor<KomgaBook>(predicate: #Predicate { $0.id == compositeId })
    if let existing = try? modelContext.fetch(descriptor).first {
      if existing.name != dto.name { existing.name = dto.name }
      if existing.url != dto.url { existing.url = dto.url }
      if existing.number != dto.number { existing.number = dto.number }
      if existing.lastModified != dto.lastModified { existing.lastModified = dto.lastModified }
      if existing.sizeBytes != dto.sizeBytes { existing.sizeBytes = dto.sizeBytes }
      if existing.size != dto.size { existing.size = dto.size }
      // Media fields
      if existing.mediaStatus != dto.media.statusRaw { existing.mediaStatus = dto.media.statusRaw }
      if existing.mediaType != dto.media.mediaType { existing.mediaType = dto.media.mediaType }
      if existing.mediaPagesCount != dto.media.pagesCount {
        existing.mediaPagesCount = dto.media.pagesCount
      }
      if existing.mediaComment != dto.media.comment { existing.mediaComment = dto.media.comment }
      if existing.mediaProfile != dto.media.mediaProfileRaw {
        existing.mediaProfile = dto.media.mediaProfileRaw
      }
      if existing.mediaEpubDivinaCompatible != dto.media.epubDivinaCompatible {
        existing.mediaEpubDivinaCompatible = dto.media.epubDivinaCompatible
      }
      if existing.mediaEpubIsKepub != dto.media.epubIsKepub {
        existing.mediaEpubIsKepub = dto.media.epubIsKepub
      }
      // Metadata fields
      if existing.metaCreated != dto.metadata.created {
        existing.metaCreated = dto.metadata.created
      }
      if existing.metaLastModified != dto.metadata.lastModified {
        existing.metaLastModified = dto.metadata.lastModified
      }
      if existing.metaTitle != dto.metadata.title { existing.metaTitle = dto.metadata.title }
      if existing.metaTitleLock != dto.metadata.titleLock {
        existing.metaTitleLock = dto.metadata.titleLock
      }
      if existing.metaSummary != dto.metadata.summary {
        existing.metaSummary = dto.metadata.summary
      }
      if existing.metaSummaryLock != dto.metadata.summaryLock {
        existing.metaSummaryLock = dto.metadata.summaryLock
      }
      if existing.metaNumber != dto.metadata.number { existing.metaNumber = dto.metadata.number }
      if existing.metaNumberLock != dto.metadata.numberLock {
        existing.metaNumberLock = dto.metadata.numberLock
      }
      if existing.metaNumberSort != dto.metadata.numberSort {
        existing.metaNumberSort = dto.metadata.numberSort
      }
      if existing.metaNumberSortLock != dto.metadata.numberSortLock {
        existing.metaNumberSortLock = dto.metadata.numberSortLock
      }
      if existing.metaReleaseDate != dto.metadata.releaseDate {
        existing.metaReleaseDate = dto.metadata.releaseDate
      }
      if existing.metaReleaseDateLock != dto.metadata.releaseDateLock {
        existing.metaReleaseDateLock = dto.metadata.releaseDateLock
      }
      let newAuthorsRaw = try? JSONEncoder().encode(dto.metadata.authors)
      if existing.metaAuthorsRaw != newAuthorsRaw { existing.metaAuthorsRaw = newAuthorsRaw }
      if existing.metaAuthorsLock != dto.metadata.authorsLock {
        existing.metaAuthorsLock = dto.metadata.authorsLock
      }
      if existing.metaTags != dto.metadata.tags { existing.metaTags = dto.metadata.tags }
      if existing.metaTagsLock != dto.metadata.tagsLock {
        existing.metaTagsLock = dto.metadata.tagsLock
      }
      if existing.metaIsbn != dto.metadata.isbn { existing.metaIsbn = dto.metadata.isbn }
      if existing.metaIsbnLock != dto.metadata.isbnLock {
        existing.metaIsbnLock = dto.metadata.isbnLock
      }
      let newLinksRaw = try? JSONEncoder().encode(dto.metadata.links)
      if existing.metaLinksRaw != newLinksRaw { existing.metaLinksRaw = newLinksRaw }
      if existing.metaLinksLock != dto.metadata.linksLock {
        existing.metaLinksLock = dto.metadata.linksLock
      }
      // ReadProgress fields
      if existing.progressPage != dto.readProgress?.page {
        existing.progressPage = dto.readProgress?.page
      }
      if existing.progressCompleted != dto.readProgress?.completed {
        existing.progressCompleted = dto.readProgress?.completed
      }
      if existing.progressReadDate != dto.readProgress?.readDate {
        existing.progressReadDate = dto.readProgress?.readDate
      }
      if existing.progressCreated != dto.readProgress?.created {
        existing.progressCreated = dto.readProgress?.created
      }
      if existing.progressLastModified != dto.readProgress?.lastModified {
        existing.progressLastModified = dto.readProgress?.lastModified
      }
      if existing.isUnavailable != dto.deleted { existing.isUnavailable = dto.deleted }
      if existing.oneshot != dto.oneshot { existing.oneshot = dto.oneshot }
      if existing.seriesTitle != dto.seriesTitle { existing.seriesTitle = dto.seriesTitle }
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
        isUnavailable: dto.deleted,
        oneshot: dto.oneshot,
        seriesTitle: dto.seriesTitle
      )
      modelContext.insert(newBook)
    }
  }

  func deleteBook(id: String, instanceId: String) {
    let compositeId = CompositeID.generate(instanceId: instanceId, id: id)
    let descriptor = FetchDescriptor<KomgaBook>(predicate: #Predicate { $0.id == compositeId })
    if let existing = try? modelContext.fetch(descriptor).first {
      modelContext.delete(existing)
    }
  }

  func upsertBooks(_ books: [Book], instanceId: String) {
    for book in books {
      upsertBook(dto: book, instanceId: instanceId)
    }
  }

  func fetchBook(id: String) async -> Book? {
    await KomgaBookStore.fetchBook(context: modelContext, id: id)
  }

  func getNextBook(instanceId: String, bookId: String, readListId: String?) async -> Book? {
    if let readListId = readListId {
      let books = await KomgaBookStore.fetchReadListBooks(
        context: modelContext, readListId: readListId, page: 0, size: 1000,
        browseOpts: ReadListBookBrowseOptions())
      if let currentIndex = books.firstIndex(where: { $0.id == bookId }),
        currentIndex + 1 < books.count
      {
        return books[currentIndex + 1]
      }
    } else if let currentBook = await fetchBook(id: bookId) {
      let seriesBooks = await KomgaBookStore.fetchSeriesBooks(
        context: modelContext, seriesId: currentBook.seriesId, page: 0, size: 1000,
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
      let books = await KomgaBookStore.fetchReadListBooks(
        context: modelContext, readListId: readListId, page: 0, size: 1000,
        browseOpts: ReadListBookBrowseOptions())
      if let currentIndex = books.firstIndex(where: { $0.id == bookId }),
        currentIndex > 0
      {
        return books[currentIndex - 1]
      }
    } else if let currentBook = await fetchBook(id: bookId) {
      let seriesBooks = await KomgaBookStore.fetchSeriesBooks(
        context: modelContext, seriesId: currentBook.seriesId, page: 0, size: 1000,
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
    let compositeId = CompositeID.generate(instanceId: instanceId, id: id)
    let descriptor = FetchDescriptor<KomgaBook>(predicate: #Predicate { $0.id == compositeId })
    return try? modelContext.fetch(descriptor).first?.pages
  }

  func fetchTOC(id: String) -> [ReaderTOCEntry]? {
    let instanceId = AppConfig.current.instanceId
    let compositeId = CompositeID.generate(instanceId: instanceId, id: id)
    let descriptor = FetchDescriptor<KomgaBook>(predicate: #Predicate { $0.id == compositeId })
    return try? modelContext.fetch(descriptor).first?.tableOfContents
  }

  func updateBookPages(bookId: String, pages: [BookPage]) {
    let instanceId = AppConfig.current.instanceId
    let compositeId = CompositeID.generate(instanceId: instanceId, id: bookId)
    let descriptor = FetchDescriptor<KomgaBook>(predicate: #Predicate { $0.id == compositeId })
    if let book = try? modelContext.fetch(descriptor).first {
      book.pages = pages
    }
  }

  func updateBookTOC(bookId: String, toc: [ReaderTOCEntry]) {
    let instanceId = AppConfig.current.instanceId
    let compositeId = CompositeID.generate(instanceId: instanceId, id: bookId)
    let descriptor = FetchDescriptor<KomgaBook>(predicate: #Predicate { $0.id == compositeId })
    if let book = try? modelContext.fetch(descriptor).first {
      book.tableOfContents = toc
    }
  }

  // MARK: - Series Operations

  func upsertSeries(dto: Series, instanceId: String) {
    let compositeId = CompositeID.generate(instanceId: instanceId, id: dto.id)
    let descriptor = FetchDescriptor<KomgaSeries>(predicate: #Predicate { $0.id == compositeId })
    if let existing = try? modelContext.fetch(descriptor).first {
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
      // SeriesMetadata fields
      if existing.metaStatus != dto.metadata.status { existing.metaStatus = dto.metadata.status }
      if existing.metaStatusLock != dto.metadata.statusLock {
        existing.metaStatusLock = dto.metadata.statusLock
      }
      if existing.metaCreated != dto.metadata.created {
        existing.metaCreated = dto.metadata.created
      }
      if existing.metaLastModified != dto.metadata.lastModified {
        existing.metaLastModified = dto.metadata.lastModified
      }
      if existing.metaTitle != dto.metadata.title { existing.metaTitle = dto.metadata.title }
      if existing.metaTitleLock != dto.metadata.titleLock {
        existing.metaTitleLock = dto.metadata.titleLock
      }
      if existing.metaTitleSort != dto.metadata.titleSort {
        existing.metaTitleSort = dto.metadata.titleSort
      }
      if existing.metaTitleSortLock != dto.metadata.titleSortLock {
        existing.metaTitleSortLock = dto.metadata.titleSortLock
      }
      if existing.metaSummary != dto.metadata.summary {
        existing.metaSummary = dto.metadata.summary
      }
      if existing.metaSummaryLock != dto.metadata.summaryLock {
        existing.metaSummaryLock = dto.metadata.summaryLock
      }
      if existing.metaReadingDirection != dto.metadata.readingDirection {
        existing.metaReadingDirection = dto.metadata.readingDirection
      }
      if existing.metaReadingDirectionLock != dto.metadata.readingDirectionLock {
        existing.metaReadingDirectionLock = dto.metadata.readingDirectionLock
      }
      if existing.metaPublisher != dto.metadata.publisher {
        existing.metaPublisher = dto.metadata.publisher
      }
      if existing.metaPublisherLock != dto.metadata.publisherLock {
        existing.metaPublisherLock = dto.metadata.publisherLock
      }
      if existing.metaAgeRating != dto.metadata.ageRating {
        existing.metaAgeRating = dto.metadata.ageRating
      }
      if existing.metaAgeRatingLock != dto.metadata.ageRatingLock {
        existing.metaAgeRatingLock = dto.metadata.ageRatingLock
      }
      if existing.metaLanguage != dto.metadata.language {
        existing.metaLanguage = dto.metadata.language
      }
      if existing.metaLanguageLock != dto.metadata.languageLock {
        existing.metaLanguageLock = dto.metadata.languageLock
      }
      if existing.metaGenres != dto.metadata.genres { existing.metaGenres = dto.metadata.genres }
      if existing.metaGenresLock != dto.metadata.genresLock {
        existing.metaGenresLock = dto.metadata.genresLock
      }
      if existing.metaTags != dto.metadata.tags { existing.metaTags = dto.metadata.tags }
      if existing.metaTagsLock != dto.metadata.tagsLock {
        existing.metaTagsLock = dto.metadata.tagsLock
      }
      if existing.metaTotalBookCount != dto.metadata.totalBookCount {
        existing.metaTotalBookCount = dto.metadata.totalBookCount
      }
      if existing.metaTotalBookCountLock != dto.metadata.totalBookCountLock {
        existing.metaTotalBookCountLock = dto.metadata.totalBookCountLock
      }
      if existing.metaSharingLabels != dto.metadata.sharingLabels {
        existing.metaSharingLabels = dto.metadata.sharingLabels
      }
      if existing.metaSharingLabelsLock != dto.metadata.sharingLabelsLock {
        existing.metaSharingLabelsLock = dto.metadata.sharingLabelsLock
      }
      let newLinksRaw = try? JSONEncoder().encode(dto.metadata.links)
      if existing.metaLinksRaw != newLinksRaw { existing.metaLinksRaw = newLinksRaw }
      if existing.metaLinksLock != dto.metadata.linksLock {
        existing.metaLinksLock = dto.metadata.linksLock
      }
      let newAlternateTitlesRaw = try? JSONEncoder().encode(dto.metadata.alternateTitles)
      if existing.metaAlternateTitlesRaw != newAlternateTitlesRaw {
        existing.metaAlternateTitlesRaw = newAlternateTitlesRaw
      }
      if existing.metaAlternateTitlesLock != dto.metadata.alternateTitlesLock {
        existing.metaAlternateTitlesLock = dto.metadata.alternateTitlesLock
      }
      // SeriesBooksMetadata fields
      if existing.booksMetaCreated != dto.booksMetadata.created {
        existing.booksMetaCreated = dto.booksMetadata.created
      }
      if existing.booksMetaLastModified != dto.booksMetadata.lastModified {
        existing.booksMetaLastModified = dto.booksMetadata.lastModified
      }
      let newAuthorsRaw = try? JSONEncoder().encode(dto.booksMetadata.authors)
      if existing.booksMetaAuthorsRaw != newAuthorsRaw {
        existing.booksMetaAuthorsRaw = newAuthorsRaw
      }
      if existing.booksMetaTags != dto.booksMetadata.tags {
        existing.booksMetaTags = dto.booksMetadata.tags
      }
      if existing.booksMetaReleaseDate != dto.booksMetadata.releaseDate {
        existing.booksMetaReleaseDate = dto.booksMetadata.releaseDate
      }
      if existing.booksMetaSummary != dto.booksMetadata.summary {
        existing.booksMetaSummary = dto.booksMetadata.summary
      }
      if existing.booksMetaSummaryNumber != dto.booksMetadata.summaryNumber {
        existing.booksMetaSummaryNumber = dto.booksMetadata.summaryNumber
      }
      if existing.isUnavailable != dto.deleted { existing.isUnavailable = dto.deleted }
      if existing.oneshot != dto.oneshot { existing.oneshot = dto.oneshot }
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
        isUnavailable: dto.deleted,
        oneshot: dto.oneshot
      )
      modelContext.insert(newSeries)
    }
  }

  func deleteSeries(id: String, instanceId: String) {
    let compositeId = CompositeID.generate(instanceId: instanceId, id: id)
    let descriptor = FetchDescriptor<KomgaSeries>(predicate: #Predicate { $0.id == compositeId })
    if let existing = try? modelContext.fetch(descriptor).first {
      modelContext.delete(existing)
    }
  }

  func upsertSeriesList(_ seriesList: [Series], instanceId: String) {
    for series in seriesList {
      upsertSeries(dto: series, instanceId: instanceId)
    }
  }

  func fetchSeries(id: String) async -> Series? {
    await KomgaSeriesStore.fetchOne(context: modelContext, seriesId: id)
  }

  func updateSeriesCollectionIds(seriesId: String, collectionIds: [String], instanceId: String) {
    let compositeId = CompositeID.generate(instanceId: instanceId, id: seriesId)
    let descriptor = FetchDescriptor<KomgaSeries>(predicate: #Predicate { $0.id == compositeId })
    if let existing = try? modelContext.fetch(descriptor).first {
      if existing.collectionIds != collectionIds {
        existing.collectionIds = collectionIds
      }
    }
  }

  func updateBookReadListIds(bookId: String, readListIds: [String], instanceId: String) {
    let compositeId = CompositeID.generate(instanceId: instanceId, id: bookId)
    let descriptor = FetchDescriptor<KomgaBook>(predicate: #Predicate { $0.id == compositeId })
    if let existing = try? modelContext.fetch(descriptor).first {
      if existing.readListIds != readListIds {
        existing.readListIds = readListIds
      }
    }
  }

  // MARK: - Collection Operations

  func upsertCollection(dto: SeriesCollection, instanceId: String) {
    let compositeId = CompositeID.generate(instanceId: instanceId, id: dto.id)
    let descriptor = FetchDescriptor<KomgaCollection>(
      predicate: #Predicate { $0.id == compositeId })
    if let existing = try? modelContext.fetch(descriptor).first {
      if existing.name != dto.name { existing.name = dto.name }
      if existing.ordered != dto.ordered { existing.ordered = dto.ordered }
      if existing.filtered != dto.filtered { existing.filtered = dto.filtered }
      if existing.lastModifiedDate != dto.lastModifiedDate {
        existing.lastModifiedDate = dto.lastModifiedDate
      }
      if existing.seriesIds != dto.seriesIds { existing.seriesIds = dto.seriesIds }
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
      modelContext.insert(newCollection)
    }
  }

  func deleteCollection(id: String, instanceId: String) {
    let compositeId = CompositeID.generate(instanceId: instanceId, id: id)
    let descriptor = FetchDescriptor<KomgaCollection>(
      predicate: #Predicate { $0.id == compositeId })
    if let existing = try? modelContext.fetch(descriptor).first {
      modelContext.delete(existing)
    }
  }

  func upsertCollections(_ collections: [SeriesCollection], instanceId: String) {
    for col in collections {
      upsertCollection(dto: col, instanceId: instanceId)
    }
  }

  // MARK: - ReadList Operations

  func upsertReadList(dto: ReadList, instanceId: String) {
    let compositeId = CompositeID.generate(instanceId: instanceId, id: dto.id)
    let descriptor = FetchDescriptor<KomgaReadList>(predicate: #Predicate { $0.id == compositeId })
    if let existing = try? modelContext.fetch(descriptor).first {
      if existing.name != dto.name { existing.name = dto.name }
      if existing.summary != dto.summary { existing.summary = dto.summary }
      if existing.ordered != dto.ordered { existing.ordered = dto.ordered }
      if existing.filtered != dto.filtered { existing.filtered = dto.filtered }
      if existing.lastModifiedDate != dto.lastModifiedDate {
        existing.lastModifiedDate = dto.lastModifiedDate
      }
      if existing.bookIds != dto.bookIds { existing.bookIds = dto.bookIds }
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
      modelContext.insert(newReadList)
    }
  }

  func deleteReadList(id: String, instanceId: String) {
    let compositeId = CompositeID.generate(instanceId: instanceId, id: id)
    let descriptor = FetchDescriptor<KomgaReadList>(predicate: #Predicate { $0.id == compositeId })
    if let existing = try? modelContext.fetch(descriptor).first {
      modelContext.delete(existing)
    }
  }

  func upsertReadLists(_ readLists: [ReadList], instanceId: String) {
    for rl in readLists {
      upsertReadList(dto: rl, instanceId: instanceId)
    }
  }

  // MARK: - Cleanup

  func clearInstanceData(instanceId: String) {
    do {
      try modelContext.delete(
        model: KomgaBook.self, where: #Predicate { $0.instanceId == instanceId })
      try modelContext.delete(
        model: KomgaSeries.self, where: #Predicate { $0.instanceId == instanceId })
      try modelContext.delete(
        model: KomgaCollection.self, where: #Predicate { $0.instanceId == instanceId })
      try modelContext.delete(
        model: KomgaReadList.self, where: #Predicate { $0.instanceId == instanceId })
      try modelContext.delete(
        model: PendingProgress.self, where: #Predicate { $0.instanceId == instanceId })

      logger.info("🗑️ Cleared all SwiftData entities for instance: \(instanceId)")
    } catch {
      logger.error("❌ Failed to clear instance data: \(error)")
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
    let compositeId = CompositeID.generate(instanceId: instanceId, id: bookId)
    let descriptor = FetchDescriptor<KomgaBook>(
      predicate: #Predicate { $0.id == compositeId }
    )

    guard let book = try? modelContext.fetch(descriptor).first else { return }
    book.downloadStatus = status
    if let downloadAt = downloadAt {
      book.downloadAt = downloadAt
    }
    if let downloadedSize = downloadedSize {
      book.downloadedSize = downloadedSize
    } else if case .notDownloaded = status {
      book.downloadedSize = 0
    }

    // Clear metadata if deleting offline
    if case .notDownloaded = status {
      book.pagesRaw = nil
      book.tocRaw = nil
    }

    // Sync series status
    if syncSeriesStatus {
      let seriesId = book.seriesId
      let compositeSeriesId = CompositeID.generate(instanceId: instanceId, id: seriesId)
      let seriesDescriptor = FetchDescriptor<KomgaSeries>(
        predicate: #Predicate { $0.id == compositeSeriesId }
      )
      if let series = try? modelContext.fetch(seriesDescriptor).first {
        syncSeriesDownloadStatus(series: series)
      }

      // Also sync readlists that contain this book
      let readListDescriptor = FetchDescriptor<KomgaReadList>(
        predicate: #Predicate { $0.instanceId == instanceId }
      )
      if let readLists = try? modelContext.fetch(readListDescriptor) {
        for readList in readLists where readList.bookIds.contains(bookId) {
          syncReadListDownloadStatus(readList: readList)
        }
      }
    }
  }

  func updateReadingProgress(bookId: String, page: Int, completed: Bool) {
    let instanceId = AppConfig.current.instanceId
    let compositeId = CompositeID.generate(instanceId: instanceId, id: bookId)
    let descriptor = FetchDescriptor<KomgaBook>(
      predicate: #Predicate { $0.id == compositeId }
    )

    if let book = try? modelContext.fetch(descriptor).first {
      book.progressPage = page
      book.progressCompleted = completed
      book.progressReadDate = Date()
      book.progressLastModified = Date()
      syncSeriesReadingStatus(seriesId: book.seriesId, instanceId: instanceId)
    }
  }

  func syncSeriesDownloadStatus(series: KomgaSeries) {
    let seriesId = series.seriesId
    let instanceId = series.instanceId

    let descriptor = FetchDescriptor<KomgaBook>(
      predicate: #Predicate { $0.seriesId == seriesId && $0.instanceId == instanceId }
    )
    let books = (try? modelContext.fetch(descriptor)) ?? []

    let totalCount = series.booksCount
    let downloadedCount = books.filter { $0.downloadStatusRaw == "downloaded" }.count
    let pendingCount = books.filter { $0.downloadStatusRaw == "pending" }.count

    series.downloadedBooks = downloadedCount
    series.pendingBooks = pendingCount
    series.downloadedSize = books.reduce(0) { $0 + $1.downloadedSize }
    series.downloadAt = books.compactMap { $0.downloadAt }.max()

    if downloadedCount == totalCount {
      series.downloadStatusRaw = "downloaded"
    } else if pendingCount > 0 {
      series.downloadStatusRaw = "pending"
    } else {
      series.downloadStatusRaw = "notDownloaded"
    }

    handlePolicyActions(series: series, books: books)
  }

  func syncSeriesDownloadStatus(seriesId: String, instanceId: String) {
    let compositeId = CompositeID.generate(instanceId: instanceId, id: seriesId)
    let descriptor = FetchDescriptor<KomgaSeries>(
      predicate: #Predicate { $0.id == compositeId }
    )
    guard let series = try? modelContext.fetch(descriptor).first else { return }
    syncSeriesDownloadStatus(series: series)
  }

  private func handlePolicyActions(series: KomgaSeries, books: [KomgaBook]) {
    let policy = series.offlinePolicy
    guard policy != .manual else { return }

    var needsSyncQueue = false
    var booksToDelete: [KomgaBook] = []
    let policyLimit = max(0, series.offlinePolicyLimit)
    let policySupportsLimit = policy == .unreadOnly || policy == .unreadOnlyAndCleanupRead

    // Sort books to ensure they are processed in order
    let sortedBooks = books.sorted { $0.metaNumberSort < $1.metaNumberSort }
    var allowedUnreadIds = Set<String>()
    if policyLimit > 0, policySupportsLimit {
      let unreadBooks = sortedBooks.filter { $0.progressCompleted != true }
      allowedUnreadIds = Set(unreadBooks.prefix(policyLimit).map { $0.bookId })
    }
    let now = Date.now

    for (index, book) in sortedBooks.enumerated() {
      let isRead = book.progressCompleted ?? false
      let isDownloaded = book.downloadStatusRaw == "downloaded"
      let isPending = book.downloadStatusRaw == "pending"
      let isFailed = book.downloadStatusRaw == "failed"

      var shouldBeOffline: Bool
      switch policy {
      case .manual:
        shouldBeOffline = (isDownloaded || isPending)
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
        shouldBeOffline = false
      }

      if shouldBeOffline {
        if !isDownloaded && !isPending && !isFailed {
          book.downloadStatusRaw = "pending"
          // Add a small increment to ensure stable sorting by downloadAt
          book.downloadAt = now.addingTimeInterval(Double(index) * 0.001)
          needsSyncQueue = true
        }
      } else if (isDownloaded || isPending) && policy == .unreadOnlyAndCleanupRead && isRead {
        // Check if any other policy wants to keep this book
        if !shouldKeepBookDueToOtherPolicies(book: book, excludeSeriesId: series.seriesId) {
          booksToDelete.append(book)
        }
      }
    }

    if needsSyncQueue {
      OfflineManager.shared.triggerSync(instanceId: series.instanceId)
    }

    if !booksToDelete.isEmpty {
      let instanceId = series.instanceId
      let seriesId = series.seriesId
      Task {
        for book in booksToDelete {
          await OfflineManager.shared.deleteBook(
            instanceId: instanceId, bookId: book.bookId, commit: false, syncSeriesStatus: false)
        }
        await DatabaseOperator.shared.syncSeriesDownloadStatus(
          seriesId: seriesId, instanceId: instanceId)
        await DatabaseOperator.shared.commit()
      }
    }
  }

  func downloadSeriesOffline(seriesId: String, instanceId: String) {
    let compositeId = CompositeID.generate(instanceId: instanceId, id: seriesId)
    let seriesDescriptor = FetchDescriptor<KomgaSeries>(
      predicate: #Predicate { $0.id == compositeId }
    )
    guard let series = try? modelContext.fetch(seriesDescriptor).first else { return }

    series.offlinePolicyRaw = SeriesOfflinePolicy.manual.rawValue

    let descriptor = FetchDescriptor<KomgaBook>(
      predicate: #Predicate { $0.seriesId == seriesId && $0.instanceId == instanceId }
    )
    let books = (try? modelContext.fetch(descriptor)) ?? []

    // Sort books by metaNumberSort before bulk assigning downloadAt
    let sortedBooks = books.sorted { $0.metaNumberSort < $1.metaNumberSort }
    let now = Date.now

    for (index, book) in sortedBooks.enumerated() {
      if AppConfig.offlineAutoDeleteRead && book.progressCompleted == true {
        continue
      }
      if book.downloadStatusRaw != "downloaded" && book.downloadStatusRaw != "pending" {
        book.downloadStatusRaw = "pending"
        // Add a small increment to ensure stable sorting by downloadAt
        book.downloadAt = now.addingTimeInterval(Double(index) * 0.001)
      }
    }

    OfflineManager.shared.triggerSync(instanceId: instanceId)
    syncSeriesDownloadStatus(series: series)
  }

  func downloadSeriesUnreadOffline(seriesId: String, instanceId: String, limit: Int) {
    let compositeId = CompositeID.generate(instanceId: instanceId, id: seriesId)
    let seriesDescriptor = FetchDescriptor<KomgaSeries>(
      predicate: #Predicate { $0.id == compositeId }
    )
    guard let series = try? modelContext.fetch(seriesDescriptor).first else { return }

    series.offlinePolicyRaw = SeriesOfflinePolicy.manual.rawValue

    let descriptor = FetchDescriptor<KomgaBook>(
      predicate: #Predicate { $0.seriesId == seriesId && $0.instanceId == instanceId }
    )
    let books = (try? modelContext.fetch(descriptor)) ?? []

    let sortedBooks = books.sorted { $0.metaNumberSort < $1.metaNumberSort }
    let unreadBooks = sortedBooks.filter { $0.progressCompleted != true }

    let limitValue = max(0, limit)
    let targetBooks = limitValue > 0 ? Array(unreadBooks.prefix(limitValue)) : unreadBooks

    let now = Date.now
    for (index, book) in targetBooks.enumerated() {
      if book.downloadStatusRaw != "downloaded" && book.downloadStatusRaw != "pending" {
        book.downloadStatusRaw = "pending"
        book.downloadAt = now.addingTimeInterval(Double(index) * 0.001)
      }
    }

    OfflineManager.shared.triggerSync(instanceId: instanceId)
    syncSeriesDownloadStatus(series: series)
  }

  func removeSeriesOffline(seriesId: String, instanceId: String) {
    let compositeId = CompositeID.generate(instanceId: instanceId, id: seriesId)
    let seriesDescriptor = FetchDescriptor<KomgaSeries>(
      predicate: #Predicate { $0.id == compositeId }
    )
    guard let series = try? modelContext.fetch(seriesDescriptor).first else { return }

    series.offlinePolicyRaw = SeriesOfflinePolicy.manual.rawValue

    let descriptor = FetchDescriptor<KomgaBook>(
      predicate: #Predicate { $0.seriesId == seriesId && $0.instanceId == instanceId }
    )
    let books = (try? modelContext.fetch(descriptor)) ?? []
    for book in books {
      book.downloadStatusRaw = "notDownloaded"
      book.downloadError = nil
      book.downloadAt = nil
      book.downloadedSize = 0
    }

    let bookIds = books.map { $0.bookId }
    Task {
      for bookId in bookIds {
        await OfflineManager.shared.deleteBook(
          instanceId: instanceId, bookId: bookId, commit: false, syncSeriesStatus: false)
      }
      await DatabaseOperator.shared.syncSeriesDownloadStatus(
        seriesId: seriesId, instanceId: instanceId)
      await DatabaseOperator.shared.commit()
    }
  }

  func removeSeriesReadOffline(seriesId: String, instanceId: String) {
    let compositeId = CompositeID.generate(instanceId: instanceId, id: seriesId)
    let seriesDescriptor = FetchDescriptor<KomgaSeries>(
      predicate: #Predicate { $0.id == compositeId }
    )
    guard let series = try? modelContext.fetch(seriesDescriptor).first else { return }

    series.offlinePolicyRaw = SeriesOfflinePolicy.manual.rawValue

    let descriptor = FetchDescriptor<KomgaBook>(
      predicate: #Predicate { $0.seriesId == seriesId && $0.instanceId == instanceId }
    )
    let books = (try? modelContext.fetch(descriptor)) ?? []

    var bookIds: [String] = []
    for book in books where book.progressCompleted == true {
      book.downloadStatusRaw = "notDownloaded"
      book.downloadError = nil
      book.downloadAt = nil
      book.downloadedSize = 0
      bookIds.append(book.bookId)
    }

    Task {
      for bookId in bookIds {
        await OfflineManager.shared.deleteBook(
          instanceId: instanceId, bookId: bookId, commit: false, syncSeriesStatus: false)
      }
      await DatabaseOperator.shared.syncSeriesDownloadStatus(
        seriesId: seriesId, instanceId: instanceId)
      await DatabaseOperator.shared.commit()
    }
  }

  func toggleSeriesDownload(seriesId: String, instanceId: String) {
    let compositeId = CompositeID.generate(instanceId: instanceId, id: seriesId)
    let descriptor = FetchDescriptor<KomgaSeries>(
      predicate: #Predicate { $0.id == compositeId }
    )
    guard let series = try? modelContext.fetch(descriptor).first else { return }

    let status = series.downloadStatus
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
    let compositeId = CompositeID.generate(instanceId: instanceId, id: seriesId)
    let descriptor = FetchDescriptor<KomgaSeries>(
      predicate: #Predicate { $0.id == compositeId }
    )
    guard let series = try? modelContext.fetch(descriptor).first else { return }

    series.offlinePolicy = policy
    if let limit {
      series.offlinePolicyLimit = max(0, limit)
    }

    if syncSeriesStatus {
      self.syncSeriesDownloadStatus(series: series)
    }
  }

  // MARK: - ReadList Download Status Operations

  func syncReadListDownloadStatus(readList: KomgaReadList) {
    let instanceId = readList.instanceId
    let bookIds = readList.bookIds
    guard !bookIds.isEmpty else {
      readList.downloadedBooks = 0
      readList.pendingBooks = 0
      readList.downloadedSize = 0
      readList.downloadAt = nil
      readList.downloadStatusRaw = "notDownloaded"
      return
    }

    // Fetch only the books that belong to this readlist
    let descriptor = FetchDescriptor<KomgaBook>(
      predicate: #Predicate { book in
        book.instanceId == instanceId && bookIds.contains(book.bookId)
      }
    )
    let books = (try? modelContext.fetch(descriptor)) ?? []

    var downloadedCount = 0
    var pendingCount = 0
    var totalSize: Int64 = 0
    var latestDownloadAt: Date?

    for book in books {
      if book.downloadStatusRaw == "downloaded" {
        downloadedCount += 1
        totalSize += book.downloadedSize
        if let downloadAt = book.downloadAt {
          if latestDownloadAt == nil || downloadAt > latestDownloadAt! {
            latestDownloadAt = downloadAt
          }
        }
      } else if book.downloadStatusRaw == "pending" {
        pendingCount += 1
      }
    }

    let totalCount = bookIds.count
    readList.downloadedBooks = downloadedCount
    readList.pendingBooks = pendingCount
    readList.downloadedSize = totalSize
    readList.downloadAt = latestDownloadAt

    if downloadedCount == totalCount && totalCount > 0 {
      readList.downloadStatusRaw = "downloaded"
    } else if pendingCount > 0 {
      readList.downloadStatusRaw = "pending"
    } else if downloadedCount > 0 {
      readList.downloadStatusRaw = "partiallyDownloaded"
    } else {
      readList.downloadStatusRaw = "notDownloaded"
    }
  }

  func syncReadListDownloadStatus(readListId: String, instanceId: String) {
    let compositeId = CompositeID.generate(instanceId: instanceId, id: readListId)
    let descriptor = FetchDescriptor<KomgaReadList>(
      predicate: #Predicate { $0.id == compositeId }
    )
    guard let readList = try? modelContext.fetch(descriptor).first else { return }
    syncReadListDownloadStatus(readList: readList)
  }

  /// Sync download status for all readlists that contain any of the given book IDs.
  func syncReadListsContainingBooks(bookIds: [String], instanceId: String) {
    guard !bookIds.isEmpty else { return }
    let bookIdSet = Set(bookIds)

    let descriptor = FetchDescriptor<KomgaReadList>(
      predicate: #Predicate { $0.instanceId == instanceId }
    )
    guard let readLists = try? modelContext.fetch(descriptor) else { return }

    for readList in readLists {
      // Check if this readlist contains any of the books
      let hasBook = readList.bookIds.contains { bookIdSet.contains($0) }
      if hasBook {
        syncReadListDownloadStatus(readList: readList)
      }
    }
  }

  /// Check if a book should be kept due to series policy.
  /// Used for conflict resolution when cleanup would be triggered but series wants to keep.
  private func shouldKeepBookDueToOtherPolicies(
    book: KomgaBook,
    excludeSeriesId: String? = nil
  ) -> Bool {
    let instanceId = book.instanceId

    // Check series policy (if not excluded)
    if book.seriesId != excludeSeriesId {
      let compositeSeriesId = CompositeID.generate(instanceId: instanceId, id: book.seriesId)
      let seriesDescriptor = FetchDescriptor<KomgaSeries>(
        predicate: #Predicate { $0.id == compositeSeriesId }
      )
      if let series = try? modelContext.fetch(seriesDescriptor).first {
        let policy = series.offlinePolicy
        // If series wants to keep (all or unreadOnly without cleanup), keep it
        if policy == .all || policy == .unreadOnly {
          return true
        }
      }
    }

    return false
  }

  func downloadReadListOffline(readListId: String, instanceId: String) {
    let compositeId = CompositeID.generate(instanceId: instanceId, id: readListId)
    let readListDescriptor = FetchDescriptor<KomgaReadList>(
      predicate: #Predicate { $0.id == compositeId }
    )
    guard let readList = try? modelContext.fetch(readListDescriptor).first else { return }

    let bookIds = readList.bookIds
    let descriptor = FetchDescriptor<KomgaBook>(
      predicate: #Predicate { $0.instanceId == instanceId }
    )
    let allBooks = (try? modelContext.fetch(descriptor)) ?? []
    let books = allBooks.filter { bookIds.contains($0.bookId) }

    let now = Date.now
    for (index, book) in books.enumerated() {
      if AppConfig.offlineAutoDeleteRead && book.progressCompleted == true {
        continue
      }
      if book.downloadStatusRaw != "downloaded" && book.downloadStatusRaw != "pending" {
        book.downloadStatusRaw = "pending"
        book.downloadAt = now.addingTimeInterval(Double(index) * 0.001)
      }
    }

    OfflineManager.shared.triggerSync(instanceId: instanceId)
    syncReadListDownloadStatus(readList: readList)
  }

  func downloadReadListUnreadOffline(readListId: String, instanceId: String, limit: Int) {
    let compositeId = CompositeID.generate(instanceId: instanceId, id: readListId)
    let readListDescriptor = FetchDescriptor<KomgaReadList>(
      predicate: #Predicate { $0.id == compositeId }
    )
    guard let readList = try? modelContext.fetch(readListDescriptor).first else { return }

    let bookIds = readList.bookIds
    let descriptor = FetchDescriptor<KomgaBook>(
      predicate: #Predicate { $0.instanceId == instanceId }
    )
    let allBooks = (try? modelContext.fetch(descriptor)) ?? []
    let books = allBooks.filter { bookIds.contains($0.bookId) }

    let sortedBooks = books.sorted { $0.metaNumberSort < $1.metaNumberSort }
    let unreadBooks = sortedBooks.filter { $0.progressCompleted != true }
    let limitValue = max(0, limit)
    let targetBooks = limitValue > 0 ? Array(unreadBooks.prefix(limitValue)) : unreadBooks

    let now = Date.now
    for (index, book) in targetBooks.enumerated() {
      if book.downloadStatusRaw != "downloaded" && book.downloadStatusRaw != "pending" {
        book.downloadStatusRaw = "pending"
        book.downloadAt = now.addingTimeInterval(Double(index) * 0.001)
      }
    }

    OfflineManager.shared.triggerSync(instanceId: instanceId)
    syncReadListDownloadStatus(readList: readList)
  }

  func removeReadListOffline(readListId: String, instanceId: String) {
    let compositeId = CompositeID.generate(instanceId: instanceId, id: readListId)
    let readListDescriptor = FetchDescriptor<KomgaReadList>(
      predicate: #Predicate { $0.id == compositeId }
    )
    guard let readList = try? modelContext.fetch(readListDescriptor).first else { return }

    let bookIds = readList.bookIds
    let descriptor = FetchDescriptor<KomgaBook>(
      predicate: #Predicate { $0.instanceId == instanceId }
    )
    let allBooks = (try? modelContext.fetch(descriptor)) ?? []
    let books = allBooks.filter { bookIds.contains($0.bookId) }

    // Only remove books that are not protected by other policies
    var bookIdsToRemove: [String] = []
    for book in books {
      if !shouldKeepBookDueToOtherPolicies(book: book) {
        book.downloadStatusRaw = "notDownloaded"
        book.downloadError = nil
        book.downloadAt = nil
        book.downloadedSize = 0
        bookIdsToRemove.append(book.bookId)
      }
    }

    Task {
      for bookId in bookIdsToRemove {
        await OfflineManager.shared.deleteBook(
          instanceId: instanceId, bookId: bookId, commit: false, syncSeriesStatus: false)
      }
      await DatabaseOperator.shared.syncReadListDownloadStatus(
        readListId: readListId, instanceId: instanceId)
      await DatabaseOperator.shared.commit()
    }
  }

  func removeReadListReadOffline(readListId: String, instanceId: String) {
    let compositeId = CompositeID.generate(instanceId: instanceId, id: readListId)
    let readListDescriptor = FetchDescriptor<KomgaReadList>(
      predicate: #Predicate { $0.id == compositeId }
    )
    guard let readList = try? modelContext.fetch(readListDescriptor).first else { return }

    let bookIds = readList.bookIds
    let descriptor = FetchDescriptor<KomgaBook>(
      predicate: #Predicate { $0.instanceId == instanceId }
    )
    let allBooks = (try? modelContext.fetch(descriptor)) ?? []
    let books = allBooks.filter { bookIds.contains($0.bookId) }

    var bookIdsToRemove: [String] = []
    for book in books where book.progressCompleted == true {
      if shouldKeepBookDueToOtherPolicies(book: book) {
        continue
      }
      book.downloadStatusRaw = "notDownloaded"
      book.downloadError = nil
      book.downloadAt = nil
      book.downloadedSize = 0
      bookIdsToRemove.append(book.bookId)
    }

    Task {
      for bookId in bookIdsToRemove {
        await OfflineManager.shared.deleteBook(
          instanceId: instanceId, bookId: bookId, commit: false, syncSeriesStatus: false)
      }
      await DatabaseOperator.shared.syncReadListDownloadStatus(
        readListId: readListId, instanceId: instanceId)
      await DatabaseOperator.shared.commit()
    }
  }

  // MARK: - Library Operations

  func replaceLibraries(_ libraries: [LibraryInfo], for instanceId: String) throws {
    let descriptor = FetchDescriptor<KomgaLibrary>(
      predicate: #Predicate { $0.instanceId == instanceId }
    )
    let existing = try modelContext.fetch(descriptor)

    var existingMap = Dictionary(
      uniqueKeysWithValues: existing.map { ($0.libraryId, $0) }
    )

    for library in libraries {
      if let existingLibrary = existingMap[library.id] {
        if existingLibrary.name != library.name {
          existingLibrary.name = library.name
        }
        existingMap.removeValue(forKey: library.id)
      } else {
        modelContext.insert(
          KomgaLibrary(
            instanceId: instanceId,
            libraryId: library.id,
            name: library.name
          ))
      }
    }

    let allLibrariesId = KomgaLibrary.allLibrariesId
    for (_, library) in existingMap {
      if library.libraryId != allLibrariesId {
        modelContext.delete(library)
      }
    }
  }

  func deleteLibrary(libraryId: String, instanceId: String) {
    // Delete the library entry
    let descriptor = FetchDescriptor<KomgaLibrary>(
      predicate: #Predicate { $0.instanceId == instanceId && $0.libraryId == libraryId }
    )
    if let existing = try? modelContext.fetch(descriptor).first {
      modelContext.delete(existing)
    }

    // Delete all books in this library
    try? modelContext.delete(
      model: KomgaBook.self,
      where: #Predicate { $0.instanceId == instanceId && $0.libraryId == libraryId }
    )

    // Delete all series in this library
    try? modelContext.delete(
      model: KomgaSeries.self,
      where: #Predicate { $0.instanceId == instanceId && $0.libraryId == libraryId }
    )
  }

  func deleteLibraries(instanceId: String?) throws {
    let descriptor: FetchDescriptor<KomgaLibrary>
    if let instanceId {
      descriptor = FetchDescriptor(
        predicate: #Predicate { $0.instanceId == instanceId }
      )
    } else {
      descriptor = FetchDescriptor()
    }
    let items = try modelContext.fetch(descriptor)
    items.forEach { modelContext.delete($0) }
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
    let allLibrariesId = KomgaLibrary.allLibrariesId
    let descriptor = FetchDescriptor<KomgaLibrary>(
      predicate: #Predicate { library in
        library.instanceId == instanceId && library.libraryId == allLibrariesId
      }
    )

    if let existing = try modelContext.fetch(descriptor).first {
      if existing.fileSize != fileSize { existing.fileSize = fileSize }
      if existing.booksCount != booksCount { existing.booksCount = booksCount }
      if existing.seriesCount != seriesCount { existing.seriesCount = seriesCount }
      if existing.sidecarsCount != sidecarsCount { existing.sidecarsCount = sidecarsCount }
      if existing.collectionsCount != collectionsCount {
        existing.collectionsCount = collectionsCount
      }
      if existing.readlistsCount != readlistsCount { existing.readlistsCount = readlistsCount }
    } else {
      let allLibrariesEntry = KomgaLibrary(
        instanceId: instanceId,
        libraryId: KomgaLibrary.allLibrariesId,
        name: "All Libraries",
        fileSize: fileSize,
        booksCount: booksCount,
        seriesCount: seriesCount,
        sidecarsCount: sidecarsCount,
        collectionsCount: collectionsCount,
        readlistsCount: readlistsCount
      )
      modelContext.insert(allLibrariesEntry)
    }
  }

  func retryFailedBooks(instanceId: String) {
    let descriptor = FetchDescriptor<KomgaBook>(
      predicate: #Predicate { $0.instanceId == instanceId && $0.downloadStatusRaw == "failed" }
    )
    if let results = try? modelContext.fetch(descriptor) {
      for book in results {
        book.downloadStatusRaw = "pending"
        book.downloadError = nil
        book.downloadAt = Date.now
      }
    }
  }

  func cancelFailedBooks(instanceId: String) {
    let descriptor = FetchDescriptor<KomgaBook>(
      predicate: #Predicate { $0.instanceId == instanceId && $0.downloadStatusRaw == "failed" }
    )
    if let results = try? modelContext.fetch(descriptor) {
      for book in results {
        book.downloadStatusRaw = "notDownloaded"
        book.downloadError = nil
        book.downloadAt = nil
      }
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
  ) throws -> KomgaInstance {
    let trimmedDisplayName = displayName?.trimmingCharacters(in: .whitespacesAndNewlines)
    let descriptor = FetchDescriptor<KomgaInstance>(
      predicate: #Predicate { instance in
        instance.serverURL == serverURL && instance.username == username
      })

    if let existing = try modelContext.fetch(descriptor).first {
      existing.authToken = authToken
      existing.isAdmin = isAdmin
      existing.authMethod = authMethod
      existing.lastUsedAt = Date()
      if let trimmedDisplayName, !trimmedDisplayName.isEmpty {
        existing.name = trimmedDisplayName
      } else if existing.name.isEmpty {
        existing.name = Self.defaultName(serverURL: serverURL, username: username)
      }
      return existing
    } else {
      let resolvedName = Self.resolvedName(
        displayName: trimmedDisplayName, serverURL: serverURL, username: username)
      let instance = KomgaInstance(
        id: instanceId ?? UUID(),
        name: resolvedName,
        serverURL: serverURL,
        username: username,
        authToken: authToken,
        isAdmin: isAdmin,
        authMethod: authMethod
      )
      modelContext.insert(instance)
      return instance
    }
  }

  private static func defaultName(serverURL: String, username: String) -> String {
    if let host = URL(string: serverURL)?.host, !host.isEmpty {
      return host
    }
    return serverURL
  }

  private static func resolvedName(
    displayName: String?, serverURL: String, username: String
  ) -> String {
    if let displayName, !displayName.isEmpty {
      return displayName
    }
    return defaultName(serverURL: serverURL, username: username)
  }

  func updateInstanceLastUsed(instanceId: String) {
    guard let uuid = UUID(uuidString: instanceId) else { return }
    let descriptor = FetchDescriptor<KomgaInstance>(
      predicate: #Predicate { instance in
        instance.id == uuid
      })
    if let instance = try? modelContext.fetch(descriptor).first {
      instance.lastUsedAt = Date()
    }
  }

  func updateSeriesLastSyncedAt(instanceId: String, date: Date) throws {
    guard let uuid = UUID(uuidString: instanceId) else { return }
    let descriptor = FetchDescriptor<KomgaInstance>(
      predicate: #Predicate { instance in
        instance.id == uuid
      })
    if let instance = try modelContext.fetch(descriptor).first {
      instance.seriesLastSyncedAt = date
    }
  }

  func updateBooksLastSyncedAt(instanceId: String, date: Date) throws {
    guard let uuid = UUID(uuidString: instanceId) else { return }
    let descriptor = FetchDescriptor<KomgaInstance>(
      predicate: #Predicate { instance in
        instance.id == uuid
      })
    if let instance = try modelContext.fetch(descriptor).first {
      instance.booksLastSyncedAt = date
    }
  }

  // MARK: - Fetch Operations

  func fetchInstance(idString: String?) -> KomgaInstance? {
    guard
      let idString,
      let uuid = UUID(uuidString: idString)
    else {
      return nil
    }

    let descriptor = FetchDescriptor<KomgaInstance>(
      predicate: #Predicate { instance in
        instance.id == uuid
      })

    return try? modelContext.fetch(descriptor).first
  }

  func getLastSyncedAt(instanceId: String) -> (series: Date, books: Date) {
    guard let instance = fetchInstance(idString: instanceId) else {
      return (Date(timeIntervalSince1970: 0), Date(timeIntervalSince1970: 0))
    }
    return (instance.seriesLastSyncedAt, instance.booksLastSyncedAt)
  }

  func fetchLibraries(instanceId: String) -> [LibraryInfo] {
    let descriptor = FetchDescriptor<KomgaLibrary>(
      predicate: #Predicate { $0.instanceId == instanceId },
      sortBy: [SortDescriptor(\KomgaLibrary.name, order: .forward)]
    )
    guard let libraries = try? modelContext.fetch(descriptor) else { return [] }
    return libraries.map { LibraryInfo(id: $0.libraryId, name: $0.name) }
  }

  // MARK: - Book Fetch Operations (for internal use, e.g., OfflineManager)

  func getDownloadStatus(bookId: String) -> DownloadStatus {
    let instanceId = AppConfig.current.instanceId
    let compositeId = CompositeID.generate(instanceId: instanceId, id: bookId)
    let descriptor = FetchDescriptor<KomgaBook>(
      predicate: #Predicate { $0.id == compositeId }
    )

    guard let book = try? modelContext.fetch(descriptor).first else { return .notDownloaded }
    return book.downloadStatus
  }

  func isBookReadCompleted(bookId: String, instanceId: String) -> Bool {
    let compositeId = CompositeID.generate(instanceId: instanceId, id: bookId)
    let descriptor = FetchDescriptor<KomgaBook>(
      predicate: #Predicate { $0.id == compositeId }
    )
    guard let book = try? modelContext.fetch(descriptor).first else { return false }
    return book.progressCompleted == true
  }

  func fetchPendingBooks(instanceId: String, limit: Int? = nil) -> [Book] {
    var descriptor = FetchDescriptor<KomgaBook>(
      predicate: #Predicate { $0.instanceId == instanceId && $0.downloadStatusRaw == "pending" },
      sortBy: [SortDescriptor(\KomgaBook.downloadAt, order: .forward)]
    )

    if let limit = limit {
      descriptor.fetchLimit = limit
    }

    do {
      let results = try modelContext.fetch(descriptor)
      return results.map { $0.toBook() }
    } catch {
      return []
    }
  }

  func fetchDownloadedBooks(instanceId: String) -> [Book] {
    let descriptor = FetchDescriptor<KomgaBook>(
      predicate: #Predicate { $0.instanceId == instanceId && $0.downloadStatusRaw == "downloaded" }
    )

    do {
      let results = try modelContext.fetch(descriptor)
      return results.map { $0.toBook() }
    } catch {
      return []
    }
  }

  func fetchFailedBooksCount(instanceId: String) -> Int {
    let descriptor = FetchDescriptor<KomgaBook>(
      predicate: #Predicate { $0.instanceId == instanceId && $0.downloadStatusRaw == "failed" }
    )
    return (try? modelContext.fetchCount(descriptor)) ?? 0
  }

  func syncSeriesReadingStatus(seriesId: String, instanceId: String) {
    let compositeSeriesId = CompositeID.generate(instanceId: instanceId, id: seriesId)
    let seriesDescriptor = FetchDescriptor<KomgaSeries>(
      predicate: #Predicate { $0.id == compositeSeriesId }
    )
    guard let series = try? modelContext.fetch(seriesDescriptor).first else { return }

    let descriptor = FetchDescriptor<KomgaBook>(
      predicate: #Predicate { $0.seriesId == seriesId && $0.instanceId == instanceId }
    )
    let books = (try? modelContext.fetch(descriptor)) ?? []

    let unreadCount = books.filter { book in
      if book.progressCompleted == true { return false }
      if (book.progressPage ?? 0) > 0 { return false }
      return true
    }.count

    let inProgressCount = books.filter { book in
      if book.progressCompleted == true { return false }
      if (book.progressPage ?? 0) > 0 { return true }
      return false
    }.count

    let readCount = books.filter { $0.progressCompleted == true }.count

    series.booksUnreadCount = unreadCount
    series.booksInProgressCount = inProgressCount
    series.booksReadCount = readCount
  }

  // MARK: - Pending Progress Operations

  func queuePendingProgress(
    instanceId: String,
    bookId: String,
    page: Int,
    completed: Bool,
    progressionData: Data? = nil
  ) {
    let compositeId = CompositeID.generate(instanceId: instanceId, id: bookId)
    let descriptor = FetchDescriptor<PendingProgress>(
      predicate: #Predicate { $0.id == compositeId }
    )

    if let existing = try? modelContext.fetch(descriptor).first {
      if existing.page != page { existing.page = page }
      if existing.completed != completed { existing.completed = completed }
      existing.createdAt = Date()  // Always update timestamp
      if existing.progressionData != progressionData { existing.progressionData = progressionData }
    } else {
      let pending = PendingProgress(
        instanceId: instanceId,
        bookId: bookId,
        page: page,
        completed: completed,
        progressionData: progressionData
      )
      modelContext.insert(pending)
    }
  }

  func fetchPendingProgress(instanceId: String, limit: Int? = nil) -> [PendingProgress] {
    var descriptor = FetchDescriptor<PendingProgress>(
      predicate: #Predicate { $0.instanceId == instanceId },
      sortBy: [SortDescriptor(\.createdAt, order: .forward)]
    )

    if let limit = limit {
      descriptor.fetchLimit = limit
    }

    return (try? modelContext.fetch(descriptor)) ?? []
  }

  func deletePendingProgress(id: String) {
    let descriptor = FetchDescriptor<PendingProgress>(
      predicate: #Predicate { $0.id == id }
    )

    if let pending = try? modelContext.fetch(descriptor).first {
      modelContext.delete(pending)
    }
  }
}
