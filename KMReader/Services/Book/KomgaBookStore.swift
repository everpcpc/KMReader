//
//  KomgaBookStore.swift
//  KMReader
//
//  Created by Komga iOS Client
//

import Foundation
import SwiftData

@MainActor
final class KomgaBookStore {
  static let shared = KomgaBookStore()

  private var container: ModelContainer?

  private init() {}

  func configure(with container: ModelContainer) {
    self.container = container
  }

  private func makeContext() throws -> ModelContext {
    guard let container else {
      throw AppErrorType.storageNotConfigured(message: "ModelContainer is not configured")
    }
    let context = ModelContext(container)
    context.autosaveEnabled = false
    return context
  }

  func fetchBooks(seriesId: String, page: Int, size: Int, sort: String? = nil) -> [Book] {
    guard let container else { return [] }
    let context = ModelContext(container)
    let instanceId = AppConfig.currentInstanceId

    // Filter by Series
    // We assume the caller provides correct filters in `sort`.
    // Default sort for books in series is usually number.

    let descriptor = FetchDescriptor<KomgaBook>(
      predicate: #Predicate { $0.seriesId == seriesId && $0.instanceId == instanceId }
    )

    // Sort logic
    // Default: number asc
    // Currently `KomgaBook` doesn't support complex dynamic sort descriptors easily.
    // We will fetch all and sort in memory if needed, or use basic sort.
    // Pagination with SwiftData on relationships is better done via the parent?
    // Actually simpler: Just query books with seriesId.

    var fetchDescriptor = descriptor
    fetchDescriptor.sortBy = [SortDescriptor(\KomgaBook.number, order: .forward)]

    // Limit and Offset
    fetchDescriptor.fetchLimit = size
    fetchDescriptor.fetchOffset = page * size

    do {
      let results = try context.fetch(fetchDescriptor)
      return results.map { $0.toBook() }
    } catch {
      return []
    }
  }

  func fetchBook(id: String) -> Book? {
    guard let container else { return nil }
    let context = ModelContext(container)
    let instanceId = AppConfig.currentInstanceId
    let compositeId = "\(instanceId)_\(id)"

    let descriptor = FetchDescriptor<KomgaBook>(
      predicate: #Predicate { $0.id == compositeId }
    )

    return try? context.fetch(descriptor).first?.toBook()
  }

  func fetchReadListBooks(readListId: String, page: Int, size: Int) -> [Book] {
    guard let container else { return [] }
    let context = ModelContext(container)
    let instanceId = AppConfig.currentInstanceId
    let rlCompositeId = "\(instanceId)_\(readListId)"

    // Find the readList first
    let descriptor = FetchDescriptor<KomgaReadList>(
      predicate: #Predicate { $0.id == rlCompositeId })
    guard let readList = try? context.fetch(descriptor).first else { return [] }

    // Get book IDs
    let bookIds = readList.bookIds

    // Pagination
    let start = page * size
    let end = min(start + size, bookIds.count)

    guard start < bookIds.count else { return [] }

    let pageIds = Array(bookIds[start..<end])

    var booksList: [Book] = []
    for bId in pageIds {
      if let b = fetchBook(id: bId) {
        booksList.append(b)
      }
    }

    return booksList
  }

  func fetchBooksList(
    search: String?,
    libraryIds: [String]?,
    browseOpts: BookBrowseOptions,
    page: Int,
    size: Int,
    sort: String?
  ) -> [Book] {
    guard let container else { return [] }
    let context = ModelContext(container)
    let instanceId = AppConfig.currentInstanceId

    // Build predicate
    // This is complex because of dynamic filters.
    // For a basic "offline first" list, we can try to approximate.
    // Or just return everything if no filters?
    // SwiftData predicates are strict.

    // Let's implement basic filtering: Library and Search.
    // Status filters are harder.

    // If we can't perfectly filter, we might show slightly different data offline than online.
    // But better than showing nothing.

    let ids = libraryIds ?? []

    var descriptor = FetchDescriptor<KomgaBook>()

    if let search = search, !search.isEmpty {
      if !ids.isEmpty {
        descriptor.predicate = #Predicate<KomgaBook> { book in
          book.instanceId == instanceId && ids.contains(book.libraryId)
            && (book.name.localizedStandardContains(search)
              || book.metaTitle.localizedStandardContains(search))
        }
      } else {
        descriptor.predicate = #Predicate<KomgaBook> { book in
          book.instanceId == instanceId
            && (book.name.localizedStandardContains(search)
              || book.metaTitle.localizedStandardContains(search))
        }
      }
    } else {
      if !ids.isEmpty {
        descriptor.predicate = #Predicate<KomgaBook> { book in
          book.instanceId == instanceId && ids.contains(book.libraryId)
        }
      } else {
        descriptor.predicate = #Predicate<KomgaBook> { book in
          book.instanceId == instanceId
        }
      }
    }

    // Sort
    // Parse sort string "field,direction"
    // Default created desc?
    if let sort = sort {
      if sort.contains("created") {
        let isAsc = !sort.contains("desc")
        descriptor.sortBy = [SortDescriptor(\KomgaBook.created, order: isAsc ? .forward : .reverse)]
      } else if sort.contains("metadata.releaseDate") {
        let isAsc = !sort.contains("desc")
        descriptor.sortBy = [
          SortDescriptor(\KomgaBook.metaReleaseDate, order: isAsc ? .forward : .reverse)
        ]
      } else if sort.contains("readProgress.readDate") {
        let isAsc = !sort.contains("desc")
        descriptor.sortBy = [
          SortDescriptor(\KomgaBook.progressReadDate, order: isAsc ? .forward : .reverse)
        ]
      } else {
        descriptor.sortBy = [SortDescriptor(\KomgaBook.name, order: .forward)]
      }
    } else {
      descriptor.sortBy = [SortDescriptor(\KomgaBook.created, order: .reverse)]
    }

    descriptor.fetchLimit = size
    descriptor.fetchOffset = page * size

    do {
      let results = try context.fetch(descriptor)
      return results.map { $0.toBook() }
    } catch {
      return []
    }
  }

  func fetchBookIds(
    libraryIds: [String]?,
    searchText: String,
    browseOpts: BookBrowseOptions,
    offset: Int,
    limit: Int
  ) -> [String] {
    guard let container else { return [] }
    let context = ModelContext(container)
    let instanceId = AppConfig.currentInstanceId

    let ids = libraryIds ?? []
    var descriptor = FetchDescriptor<KomgaBook>()

    if !searchText.isEmpty {
      if !ids.isEmpty {
        descriptor.predicate = #Predicate<KomgaBook> { book in
          book.instanceId == instanceId && ids.contains(book.libraryId)
            && (book.name.localizedStandardContains(searchText)
              || book.metaTitle.localizedStandardContains(searchText))
        }
      } else {
        descriptor.predicate = #Predicate<KomgaBook> { book in
          book.instanceId == instanceId
            && (book.name.localizedStandardContains(searchText)
              || book.metaTitle.localizedStandardContains(searchText))
        }
      }
    } else {
      if !ids.isEmpty {
        descriptor.predicate = #Predicate<KomgaBook> { book in
          book.instanceId == instanceId && ids.contains(book.libraryId)
        }
      } else {
        descriptor.predicate = #Predicate<KomgaBook> { book in
          book.instanceId == instanceId
        }
      }
    }

    // Sort
    let sort = browseOpts.sortString
    if sort.contains("created") {
      let isAsc = !sort.contains("desc")
      descriptor.sortBy = [SortDescriptor(\KomgaBook.created, order: isAsc ? .forward : .reverse)]
    } else if sort.contains("metadata.releaseDate") {
      let isAsc = !sort.contains("desc")
      descriptor.sortBy = [
        SortDescriptor(\KomgaBook.metaReleaseDate, order: isAsc ? .forward : .reverse)
      ]
    } else {
      descriptor.sortBy = [SortDescriptor(\KomgaBook.name, order: .forward)]
    }

    descriptor.fetchLimit = limit
    descriptor.fetchOffset = offset

    do {
      let results = try context.fetch(descriptor)
      return results.map { $0.bookId }
    } catch {
      return []
    }
  }

  func fetchBooksByIds(ids: [String], instanceId: String) -> [KomgaBook] {
    guard let container, !ids.isEmpty else { return [] }
    let context = ModelContext(container)

    let descriptor = FetchDescriptor<KomgaBook>(
      predicate: #Predicate<KomgaBook> { book in
        book.instanceId == instanceId && ids.contains(book.bookId)
      }
    )

    do {
      let results = try context.fetch(descriptor)
      let idToIndex = Dictionary(
        uniqueKeysWithValues: ids.enumerated().map { ($0.element, $0.offset) })
      return results.sorted {
        (idToIndex[$0.bookId] ?? Int.max) < (idToIndex[$1.bookId] ?? Int.max)
      }
    } catch {
      return []
    }
  }

  func fetchKeepReadingBookIds(
    libraryIds: [String],
    offset: Int,
    limit: Int
  ) -> [String] {
    guard let container else { return [] }
    let context = ModelContext(container)
    let instanceId = AppConfig.currentInstanceId

    let ids = libraryIds
    var descriptor = FetchDescriptor<KomgaBook>()

    if !ids.isEmpty {
      descriptor.predicate = #Predicate<KomgaBook> { book in
        book.instanceId == instanceId && ids.contains(book.libraryId)
          && book.progressReadDate != nil && book.progressCompleted == false
      }
    } else {
      descriptor.predicate = #Predicate<KomgaBook> { book in
        book.instanceId == instanceId
          && book.progressReadDate != nil && book.progressCompleted == false
      }
    }

    descriptor.sortBy = [SortDescriptor(\KomgaBook.progressReadDate, order: .reverse)]
    descriptor.fetchLimit = limit
    descriptor.fetchOffset = offset

    do {
      let results = try context.fetch(descriptor)
      return results.map { $0.bookId }
    } catch {
      return []
    }
  }

  func fetchRecentBookIds(
    libraryIds: [String],
    offset: Int,
    limit: Int
  ) -> [String] {
    guard let container else { return [] }
    let context = ModelContext(container)
    let instanceId = AppConfig.currentInstanceId

    let ids = libraryIds
    var descriptor = FetchDescriptor<KomgaBook>()

    if !ids.isEmpty {
      descriptor.predicate = #Predicate<KomgaBook> { book in
        book.instanceId == instanceId && ids.contains(book.libraryId)
      }
    } else {
      descriptor.predicate = #Predicate<KomgaBook> { book in
        book.instanceId == instanceId
      }
    }

    descriptor.sortBy = [SortDescriptor(\KomgaBook.created, order: .reverse)]
    descriptor.fetchLimit = limit
    descriptor.fetchOffset = offset

    do {
      let results = try context.fetch(descriptor)
      return results.map { $0.bookId }
    } catch {
      return []
    }
  }

  // MARK: - Offline Download Status

  /// Get the download status of a book.
  func getDownloadStatus(bookId: String) -> DownloadStatus {
    guard let container else { return .notDownloaded }
    let context = ModelContext(container)
    let instanceId = AppConfig.currentInstanceId
    let compositeId = "\(instanceId)_\(bookId)"

    let descriptor = FetchDescriptor<KomgaBook>(
      predicate: #Predicate { $0.id == compositeId }
    )

    guard let book = try? context.fetch(descriptor).first else { return .notDownloaded }
    return book.downloadStatus
  }

  /// Check if a book is downloaded.
  func isBookDownloaded(bookId: String) -> Bool {
    if case .downloaded = getDownloadStatus(bookId: bookId) {
      return true
    }
    return false
  }

  /// Update the download status of a book.
  /// - Parameters:
  ///   - bookId: The book ID to update.
  ///   - status: The new download status.
  ///   - downloadAt: Optional download timestamp.
  ///   - downloadedSize: Optional downloaded size.
  ///   - commit: If true, saves the context immediately. Set to false for batching updates.
  func updateDownloadStatus(
    bookId: String, status: DownloadStatus, downloadAt: Date? = nil, downloadedSize: Int64? = nil,
    commit: Bool = true
  ) {
    guard let container else { return }
    let context = ModelContext(container)
    context.autosaveEnabled = false
    let instanceId = AppConfig.currentInstanceId
    let compositeId = "\(instanceId)_\(bookId)"

    let descriptor = FetchDescriptor<KomgaBook>(
      predicate: #Predicate { $0.id == compositeId }
    )

    guard let book = try? context.fetch(descriptor).first else { return }
    book.downloadStatus = status
    if let downloadAt = downloadAt {
      book.downloadAt = downloadAt
    }
    if let downloadedSize = downloadedSize {
      book.downloadedSize = downloadedSize
    } else if case .notDownloaded = status {
      book.downloadedSize = 0
    }
    if commit {
      try? context.save()
      // Sync series status
      let seriesId = book.seriesId
      let compositeSeriesId = "\(instanceId)_\(seriesId)"
      let seriesDescriptor = FetchDescriptor<KomgaSeries>(
        predicate: #Predicate { $0.id == compositeSeriesId }
      )
      if let series = try? context.fetch(seriesDescriptor).first {
        syncSeriesDownloadStatus(series: series, context: context)
        try? context.save()
      }
    }
  }

  /// Sync the download status and downloaded books count for a series.
  func syncSeriesDownloadStatus(series: KomgaSeries, context: ModelContext) {
    let seriesId = series.seriesId
    let instanceId = series.instanceId

    // Explicitly fetch books for this series to ensure relationship is populated in current context
    let descriptor = FetchDescriptor<KomgaBook>(
      predicate: #Predicate { $0.seriesId == seriesId && $0.instanceId == instanceId }
    )
    let books = (try? context.fetch(descriptor)) ?? []

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

    // Handle policy-based actions
    handlePolicyActions(series: series, books: books, context: context)
  }

  /// Handle automatic download/delete actions based on series policy.
  func handlePolicyActions(series: KomgaSeries, books: [KomgaBook], context: ModelContext) {
    let policy = series.offlinePolicy
    guard policy != .manual else { return }

    var needsSyncQueue = false
    var booksToDelete: [KomgaBook] = []

    for book in books {
      let isRead = book.progressCompleted ?? false
      let isDownloaded = book.downloadStatusRaw == "downloaded"
      let isPending = book.downloadStatusRaw == "pending"
      let isFailed = book.downloadStatusRaw == "failed"

      let shouldBeOffline: Bool
      switch policy {
      case .manual:
        shouldBeOffline = (isDownloaded || isPending)
      case .unreadOnly, .unreadOnlyAndCleanupRead:
        shouldBeOffline = !isRead
      case .all:
        shouldBeOffline = true
      }

      if shouldBeOffline {
        if !isDownloaded && !isPending && !isFailed {
          book.downloadStatusRaw = "pending"
          book.downloadAt = .now
          needsSyncQueue = true
        }
      } else {
        if (isDownloaded || isPending) && policy == .unreadOnlyAndCleanupRead {
          booksToDelete.append(book)
        }
      }
    }

    if needsSyncQueue {
      OfflineManager.shared.triggerSync(instanceId: series.instanceId)
    }

    if !booksToDelete.isEmpty {
      let instanceId = series.instanceId
      Task {
        for book in booksToDelete {
          await OfflineManager.shared.deleteBook(instanceId: instanceId, bookId: book.bookId)
        }
      }
    }
  }

  /// Fetch all pending books for the current instance.
  func fetchPendingBooks(limit: Int? = nil) -> [Book] {
    guard let container else { return [] }
    let context = ModelContext(container)
    let instanceId = AppConfig.currentInstanceId

    var descriptor = FetchDescriptor<KomgaBook>(
      predicate: #Predicate { $0.instanceId == instanceId && $0.downloadStatusRaw == "pending" },
      sortBy: [SortDescriptor(\KomgaBook.downloadAt, order: .forward)]
    )

    if let limit = limit {
      descriptor.fetchLimit = limit
    }

    do {
      let results = try context.fetch(descriptor)
      return results.map { $0.toBook() }
    } catch {
      return []
    }
  }

  /// Fetch all downloaded books for the current instance.
  func fetchDownloadedBooks() -> [Book] {
    guard let container else { return [] }
    let context = ModelContext(container)
    let instanceId = AppConfig.currentInstanceId

    let descriptor = FetchDescriptor<KomgaBook>(
      predicate: #Predicate { $0.instanceId == instanceId && $0.downloadStatusRaw == "downloaded" }
    )

    do {
      let results = try context.fetch(descriptor)
      return results.map { $0.toBook() }
    } catch {
      return []
    }
  }

  /// Download all books in a series.
  func downloadAllBooks(series: KomgaSeries, context: ModelContext) {
    // Reset policy to manual
    series.offlinePolicyRaw = SeriesOfflinePolicy.manual.rawValue
    try? context.save()

    let seriesId = series.seriesId
    let instanceId = series.instanceId
    let descriptor = FetchDescriptor<KomgaBook>(
      predicate: #Predicate { $0.seriesId == seriesId && $0.instanceId == instanceId }
    )
    let books = (try? context.fetch(descriptor)) ?? []
    for book in books {
      if book.downloadStatusRaw != "downloaded" && book.downloadStatusRaw != "pending" {
        book.downloadStatusRaw = "pending"
        book.downloadAt = Date.now
      }
    }

    OfflineManager.shared.triggerSync(instanceId: instanceId)
    syncSeriesDownloadStatus(series: series, context: context)
    try? context.save()
  }

  /// Remove all downloaded books in a series.
  func removeAllBooks(series: KomgaSeries, context: ModelContext) {
    // Reset policy to manual
    series.offlinePolicyRaw = SeriesOfflinePolicy.manual.rawValue
    try? context.save()

    let seriesId = series.seriesId
    let instanceId = series.instanceId
    let descriptor = FetchDescriptor<KomgaBook>(
      predicate: #Predicate { $0.seriesId == seriesId && $0.instanceId == instanceId }
    )

    let books = (try? context.fetch(descriptor)) ?? []
    for book in books {
      book.downloadStatusRaw = "notDownloaded"
      book.downloadError = nil
      book.downloadAt = nil
      book.downloadedSize = 0
    }
    try? context.save()

    Task {
      for book in books {
        await OfflineManager.shared.deleteBook(instanceId: instanceId, bookId: book.bookId)
      }
    }

    syncSeriesDownloadStatus(series: series, context: context)
    try? context.save()
  }

  /// Toggle download for all books in a series.
  func toggleSeriesDownload(series: KomgaSeries, context: ModelContext) {
    let status = series.downloadStatus
    switch status {
    case .downloaded, .partiallyDownloaded, .pending:
      removeAllBooks(series: series, context: context)
    case .notDownloaded:
      downloadAllBooks(series: series, context: context)
    }
  }
}
