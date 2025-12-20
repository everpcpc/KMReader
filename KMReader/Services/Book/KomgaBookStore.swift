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
    return ModelContext(container)
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

    let libraryId = libraryIds?.first

    var descriptor = FetchDescriptor<KomgaBook>()

    // We need to construct predicate based on filters.
    // Swift 5.9 macros make this hard to compose dynamically.
    // We will do a broad fetch and filter in memory? Not efficient for pagination.

    // Strategy: Only filter by Instance ID and Text Search for now.
    // Users can see "more" than expected offline if they have complex filters set?
    // Or we just support basic offline browsing.

    if let search = search, !search.isEmpty {
      if let libraryId = libraryId {
        descriptor.predicate = #Predicate<KomgaBook> { book in
          book.instanceId == instanceId && book.libraryId == libraryId
            && (book.name.contains(search) || book.metaTitle.contains(search))
        }
      } else {
        descriptor.predicate = #Predicate<KomgaBook> { book in
          book.instanceId == instanceId
            && (book.name.contains(search) || book.metaTitle.contains(search))
        }
      }
    } else {
      if let libraryId = libraryId {
        descriptor.predicate = #Predicate<KomgaBook> { book in
          book.instanceId == instanceId && book.libraryId == libraryId
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
  func updateDownloadStatus(
    bookId: String, status: DownloadStatus, downloadAt: Date? = nil, downloadedSize: Int64? = nil
  ) {
    guard let container else { return }
    let context = ModelContext(container)
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
      book.downloadedSize = nil
    }
    try? context.save()
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
}
