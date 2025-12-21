//
//  KomgaBookStore.swift
//  KMReader
//
//  Created by Komga iOS Client
//

import Foundation
import SwiftData

/// Provides read-only fetch operations for KomgaBook data.
/// All View-facing fetch methods require a ModelContext from the caller.
enum KomgaBookStore {

  static func fetchBooks(
    context: ModelContext,
    seriesId: String,
    page: Int,
    size: Int,
    sort: String? = nil
  ) -> [Book] {
    let instanceId = AppConfig.currentInstanceId

    var descriptor = FetchDescriptor<KomgaBook>(
      predicate: #Predicate { $0.seriesId == seriesId && $0.instanceId == instanceId }
    )
    descriptor.sortBy = [SortDescriptor(\KomgaBook.number, order: .forward)]
    descriptor.fetchLimit = size
    descriptor.fetchOffset = page * size

    do {
      let results = try context.fetch(descriptor)
      return results.map { $0.toBook() }
    } catch {
      return []
    }
  }

  static func fetchBook(context: ModelContext, id: String) -> Book? {
    let instanceId = AppConfig.currentInstanceId
    let compositeId = "\(instanceId)_\(id)"

    let descriptor = FetchDescriptor<KomgaBook>(
      predicate: #Predicate { $0.id == compositeId }
    )

    return try? context.fetch(descriptor).first?.toBook()
  }

  static func fetchReadListBooks(
    context: ModelContext,
    readListId: String,
    page: Int,
    size: Int
  ) -> [Book] {
    let instanceId = AppConfig.currentInstanceId
    let rlCompositeId = "\(instanceId)_\(readListId)"

    let descriptor = FetchDescriptor<KomgaReadList>(
      predicate: #Predicate { $0.id == rlCompositeId })
    guard let readList = try? context.fetch(descriptor).first else { return [] }

    let bookIds = readList.bookIds
    let start = page * size
    let end = min(start + size, bookIds.count)

    guard start < bookIds.count else { return [] }

    let pageIds = Array(bookIds[start..<end])

    var booksList: [Book] = []
    for bId in pageIds {
      if let b = fetchBook(context: context, id: bId) {
        booksList.append(b)
      }
    }

    return booksList
  }

  static func fetchBooksList(
    context: ModelContext,
    search: String?,
    libraryIds: [String]?,
    browseOpts: BookBrowseOptions,
    page: Int,
    size: Int,
    sort: String?
  ) -> [Book] {
    let instanceId = AppConfig.currentInstanceId
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

  static func fetchBookIds(
    context: ModelContext,
    libraryIds: [String]?,
    searchText: String,
    browseOpts: BookBrowseOptions,
    offset: Int,
    limit: Int
  ) -> [String] {
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

  static func fetchBooksByIds(
    context: ModelContext,
    ids: [String],
    instanceId: String
  ) -> [KomgaBook] {
    guard !ids.isEmpty else { return [] }

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

  static func fetchKeepReadingBookIds(
    context: ModelContext,
    libraryIds: [String],
    offset: Int,
    limit: Int
  ) -> [String] {
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

  static func fetchRecentlyReleasedBookIds(
    context: ModelContext,
    libraryIds: [String],
    offset: Int,
    limit: Int
  ) -> [String] {
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

    descriptor.sortBy = [SortDescriptor(\KomgaBook.metaReleaseDate, order: .reverse)]
    descriptor.fetchLimit = limit
    descriptor.fetchOffset = offset

    do {
      let results = try context.fetch(descriptor)
      return results.map { $0.bookId }
    } catch {
      return []
    }
  }

  static func fetchRecentlyReadBookIds(
    context: ModelContext,
    libraryIds: [String],
    offset: Int,
    limit: Int
  ) -> [String] {
    let instanceId = AppConfig.currentInstanceId
    let ids = libraryIds
    var descriptor = FetchDescriptor<KomgaBook>()

    if !ids.isEmpty {
      descriptor.predicate = #Predicate<KomgaBook> { book in
        book.instanceId == instanceId && ids.contains(book.libraryId)
          && book.progressReadDate != nil
      }
    } else {
      descriptor.predicate = #Predicate<KomgaBook> { book in
        book.instanceId == instanceId
          && book.progressReadDate != nil
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

  static func fetchRecentlyAddedBookIds(
    context: ModelContext,
    libraryIds: [String],
    offset: Int,
    limit: Int
  ) -> [String] {
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

  /// Get download status - uses context for internal lookup
  static func getDownloadStatus(context: ModelContext, bookId: String) -> DownloadStatus {
    let instanceId = AppConfig.currentInstanceId
    let compositeId = "\(instanceId)_\(bookId)"

    let descriptor = FetchDescriptor<KomgaBook>(
      predicate: #Predicate { $0.id == compositeId }
    )

    guard let book = try? context.fetch(descriptor).first else { return .notDownloaded }
    return book.downloadStatus
  }

  static func isBookDownloaded(context: ModelContext, bookId: String) -> Bool {
    if case .downloaded = getDownloadStatus(context: context, bookId: bookId) {
      return true
    }
    return false
  }

  static func fetchPendingBooks(context: ModelContext, limit: Int? = nil) -> [Book] {
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

  static func fetchDownloadedBooks(context: ModelContext) -> [Book] {
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
