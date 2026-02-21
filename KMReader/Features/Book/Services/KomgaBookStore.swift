//
// KomgaBookStore.swift
//
//

import Dependencies
import Foundation
import SQLiteData

/// Provides read-only fetch operations for KomgaBook data.
enum KomgaBookStore {

  nonisolated static func fetchSeriesBooks(
    seriesId: String,
    page: Int,
    size: Int,
    browseOpts: BookBrowseOptions
  ) -> [Book] {
    let instanceId = AppConfig.current.instanceId

    do {
      var records = try fetchBooksForInstance(instanceId: instanceId, seriesId: seriesId)
      let stateMap = fetchBookLocalStateMap(books: records)
      records = sortedBooks(records, sort: browseOpts.sortString, stateMap: stateMap)
      records = records.filter { passesReadFilters(book: $0, browseOpts: browseOpts) }
      let pageSlice = paginate(records, page: page, size: size)
      return pageSlice.map { $0.toBook() }
    } catch {
      return []
    }
  }

  nonisolated static func fetchBook(id: String) -> Book? {
    let instanceId = AppConfig.current.instanceId

    do {
      @Dependency(\.defaultDatabase) var database
      return try database.read { db in
        try KomgaBookRecord
          .where { $0.instanceId.eq(instanceId) && $0.bookId.eq(id) }
          .fetchOne(db)?
          .toBook()
      }
    } catch {
      return nil
    }
  }

  nonisolated static func fetchReadListBooks(
    readListId: String,
    page: Int,
    size: Int,
    browseOpts: ReadListBookBrowseOptions
  ) -> [Book] {
    let instanceId = AppConfig.current.instanceId

    do {
      @Dependency(\.defaultDatabase) var database
      guard
        let readList = try database.read({ db in
          try KomgaReadListRecord
            .where { $0.instanceId.eq(instanceId) && $0.readListId.eq(readListId) }
            .fetchOne(db)
        })
      else {
        return []
      }

      let bookIds = readList.bookIds
      let allBooks = fetchBooksByIds(ids: bookIds, instanceId: instanceId)
      let filtered = allBooks.filter { passesReadListFilters(book: $0, browseOpts: browseOpts) }

      let start = page * size
      guard start < filtered.count else { return [] }
      let end = min(start + size, filtered.count)
      return filtered[start..<end].map { $0.toBook() }
    } catch {
      return []
    }
  }

  nonisolated static func fetchBooksList(
    search: String?,
    libraryIds: [String]?,
    browseOpts _: BookBrowseOptions,
    page: Int,
    size: Int,
    sort: String?
  ) -> [Book] {
    let instanceId = AppConfig.current.instanceId

    do {
      var records = try fetchBooksForInstance(
        instanceId: instanceId,
        libraryIds: libraryIds,
        seriesId: nil
      )

      if let search, !search.isEmpty {
        records = records.filter {
          $0.name.localizedStandardContains(search)
            || $0.metaTitle.localizedStandardContains(search)
        }
      }

      let stateMap = fetchBookLocalStateMap(books: records)
      records = sortedBooks(records, sort: sort ?? "created,desc", stateMap: stateMap)
      let pageSlice = paginate(records, page: page, size: size)
      return pageSlice.map { $0.toBook() }
    } catch {
      return []
    }
  }

  nonisolated static func fetchBookIds(
    libraryIds: [String]?,
    searchText: String,
    browseOpts: BookBrowseOptions,
    offset: Int,
    limit: Int,
    offlineOnly: Bool = false
  ) -> [String] {
    let instanceId = AppConfig.current.instanceId

    do {
      var records = try fetchBooksForInstance(
        instanceId: instanceId,
        libraryIds: libraryIds,
        seriesId: nil
      )

      if !searchText.isEmpty {
        records = records.filter {
          $0.name.localizedStandardContains(searchText)
            || $0.metaTitle.localizedStandardContains(searchText)
        }
      }

      let stateMap = fetchBookLocalStateMap(books: records)

      if offlineOnly {
        records = records.filter {
          let status = stateMap[$0.bookId]?.downloadStatusRaw ?? "notDownloaded"
          return status == "downloaded" || status == "pending"
        }
      }

      records = sortedBooks(records, sort: browseOpts.sortString, stateMap: stateMap)
      let slice = paginate(records, offset: offset, limit: limit)
      return slice.map { $0.bookId }
    } catch {
      return []
    }
  }

  nonisolated private static func fetchBooksByIds(
    ids: [String],
    instanceId: String
  ) -> [KomgaBookRecord] {
    guard !ids.isEmpty else { return [] }

    do {
      @Dependency(\.defaultDatabase) var database
      let records = try database.read { db in
        try KomgaBookRecord
          .where { $0.instanceId.eq(instanceId) && $0.bookId.in(ids) }
          .fetchAll(db)
      }

      let idToIndex = Dictionary(uniqueKeysWithValues: ids.enumerated().map { ($0.element, $0.offset) })
      return records.sorted {
        (idToIndex[$0.bookId] ?? Int.max) < (idToIndex[$1.bookId] ?? Int.max)
      }
    } catch {
      return []
    }
  }

  nonisolated private static func fetchBookLocalStateMap(
    books: [KomgaBookRecord]
  ) -> [String: KomgaBookLocalStateRecord] {
    guard !books.isEmpty else { return [:] }

    do {
      let grouped = Dictionary(grouping: books, by: \.instanceId)
      @Dependency(\.defaultDatabase) var database
      return try database.read { db in
        var stateMap: [String: KomgaBookLocalStateRecord] = [:]
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
    } catch {
      return [:]
    }
  }

  nonisolated static func fetchKeepReadingBookIds(
    libraryIds: [String],
    offset: Int,
    limit: Int
  ) -> [String] {
    let instanceId = AppConfig.current.instanceId

    do {
      var records = try fetchBooksForInstance(
        instanceId: instanceId,
        libraryIds: libraryIds.isEmpty ? nil : libraryIds,
        seriesId: nil
      )
      records = records.filter { $0.progressReadDate != nil && $0.progressCompleted == false }
      records.sort { compareOptionalDate($0.progressReadDate, $1.progressReadDate, ascending: false) }
      let slice = paginate(records, offset: offset, limit: limit)
      return slice.map { $0.bookId }
    } catch {
      return []
    }
  }

  nonisolated static func fetchRecentlyReleasedBookIds(
    libraryIds: [String],
    offset: Int,
    limit: Int
  ) -> [String] {
    let instanceId = AppConfig.current.instanceId

    do {
      var records = try fetchBooksForInstance(
        instanceId: instanceId,
        libraryIds: libraryIds.isEmpty ? nil : libraryIds,
        seriesId: nil
      )
      records.sort {
        compareOptionalStringDate($0.metaReleaseDate, $1.metaReleaseDate, ascending: false)
      }
      let slice = paginate(records, offset: offset, limit: limit)
      return slice.map { $0.bookId }
    } catch {
      return []
    }
  }

  nonisolated static func fetchRecentlyReadBookIds(
    libraryIds: [String],
    offset: Int,
    limit: Int
  ) -> [String] {
    let instanceId = AppConfig.current.instanceId

    do {
      var records = try fetchBooksForInstance(
        instanceId: instanceId,
        libraryIds: libraryIds.isEmpty ? nil : libraryIds,
        seriesId: nil
      )
      records = records.filter { $0.progressReadDate != nil }
      records.sort { compareOptionalDate($0.progressReadDate, $1.progressReadDate, ascending: false) }
      let slice = paginate(records, offset: offset, limit: limit)
      return slice.map { $0.bookId }
    } catch {
      return []
    }
  }

  nonisolated static func fetchRecentlyAddedBookIds(
    libraryIds: [String],
    offset: Int,
    limit: Int
  ) -> [String] {
    let instanceId = AppConfig.current.instanceId

    do {
      var records = try fetchBooksForInstance(
        instanceId: instanceId,
        libraryIds: libraryIds.isEmpty ? nil : libraryIds,
        seriesId: nil
      )
      records.sort { $0.created > $1.created }
      let slice = paginate(records, offset: offset, limit: limit)
      return slice.map { $0.bookId }
    } catch {
      return []
    }
  }

  nonisolated static func getDownloadStatus(bookId: String) -> DownloadStatus {
    let instanceId = AppConfig.current.instanceId

    do {
      @Dependency(\.defaultDatabase) var database
      let state = try database.read { db in
        try KomgaBookLocalStateRecord
          .where { $0.instanceId.eq(instanceId) && $0.bookId.eq(bookId) }
          .fetchOne(db)
      }
      return (state ?? .empty(instanceId: instanceId, bookId: bookId)).downloadStatus
    } catch {
      return .notDownloaded
    }
  }

  nonisolated static func isBookDownloaded(bookId: String) -> Bool {
    if case .downloaded = getDownloadStatus(bookId: bookId) {
      return true
    }
    return false
  }

  nonisolated static func fetchPendingBooks(limit: Int? = nil) -> [Book] {
    let instanceId = AppConfig.current.instanceId

    do {
      var records = try fetchBooksForInstance(instanceId: instanceId)
      let stateMap = fetchBookLocalStateMap(books: records)
      records = records.filter { (stateMap[$0.bookId]?.downloadStatusRaw ?? "notDownloaded") == "pending" }
      records.sort {
        compareOptionalDate(
          stateMap[$0.bookId]?.downloadAt,
          stateMap[$1.bookId]?.downloadAt,
          ascending: true
        )
      }

      if let limit {
        records = Array(records.prefix(limit))
      }

      return records.map { $0.toBook() }
    } catch {
      return []
    }
  }

  nonisolated static func fetchDownloadedBooks() -> [Book] {
    let instanceId = AppConfig.current.instanceId

    do {
      let records = try fetchBooksForInstance(instanceId: instanceId)
      let stateMap = fetchBookLocalStateMap(books: records)
      return
        records
        .filter { (stateMap[$0.bookId]?.downloadStatusRaw ?? "notDownloaded") == "downloaded" }
        .map { $0.toBook() }
    } catch {
      return []
    }
  }

  nonisolated private static func fetchBooksForInstance(
    instanceId: String,
    libraryIds: [String]? = nil,
    seriesId: String? = nil
  ) throws -> [KomgaBookRecord] {
    @Dependency(\.defaultDatabase) var database

    return try database.read { db in
      switch (libraryIds, seriesId) {
      case (let libraryIds?, let seriesId?) where !libraryIds.isEmpty:
        return
          try KomgaBookRecord
          .where {
            $0.instanceId.eq(instanceId)
              && $0.libraryId.in(libraryIds)
              && $0.seriesId.eq(seriesId)
          }
          .fetchAll(db)
      case (let libraryIds?, nil) where !libraryIds.isEmpty:
        return
          try KomgaBookRecord
          .where {
            $0.instanceId.eq(instanceId)
              && $0.libraryId.in(libraryIds)
          }
          .fetchAll(db)
      case (nil, let seriesId?):
        return
          try KomgaBookRecord
          .where {
            $0.instanceId.eq(instanceId)
              && $0.seriesId.eq(seriesId)
          }
          .fetchAll(db)
      default:
        return
          try KomgaBookRecord
          .where { $0.instanceId.eq(instanceId) }
          .fetchAll(db)
      }
    }
  }

  nonisolated private static func sortedBooks(
    _ books: [KomgaBookRecord],
    sort: String,
    stateMap: [String: KomgaBookLocalStateRecord] = [:]
  ) -> [KomgaBookRecord] {
    if sort.contains("created") {
      let isAsc = !sort.contains("desc")
      return books.sorted {
        isAsc ? ($0.created < $1.created) : ($0.created > $1.created)
      }
    }

    if sort.contains("metadata.releaseDate") {
      let isAsc = !sort.contains("desc")
      return books.sorted {
        compareOptionalStringDate($0.metaReleaseDate, $1.metaReleaseDate, ascending: isAsc)
      }
    }

    if sort.contains("readProgress.readDate") {
      let isAsc = !sort.contains("desc")
      return books.sorted {
        compareOptionalDate($0.progressReadDate, $1.progressReadDate, ascending: isAsc)
      }
    }

    if sort.contains("downloadAt") {
      let isAsc = !sort.contains("desc")
      return books.sorted {
        compareOptionalDate(
          stateMap[$0.bookId]?.downloadAt,
          stateMap[$1.bookId]?.downloadAt,
          ascending: isAsc
        )
      }
    }

    if sort.contains("metaNumberSort") || sort.contains("number") {
      return books.sorted {
        $0.metaNumberSort < $1.metaNumberSort
      }
    }

    return books.sorted {
      $0.name.localizedStandardCompare($1.name) == .orderedAscending
    }
  }

  nonisolated private static func passesReadFilters(book: KomgaBookRecord, browseOpts: BookBrowseOptions) -> Bool {
    if let deletedState = browseOpts.deletedFilter.effectiveBool {
      if book.deleted != deletedState { return false }
    }

    if let oneshotState = browseOpts.oneshotFilter.effectiveBool {
      if book.oneshot != oneshotState { return false }
    }

    let status: ReadStatus
    if let completed = book.progressCompleted, completed {
      status = .read
    } else if book.progressReadDate != nil {
      status = .inProgress
    } else {
      status = .unread
    }

    if !browseOpts.includeReadStatuses.isEmpty {
      if !browseOpts.includeReadStatuses.contains(status) { return false }
    }

    if !browseOpts.excludeReadStatuses.isEmpty {
      if browseOpts.excludeReadStatuses.contains(status) { return false }
    }

    return true
  }

  nonisolated private static func passesReadListFilters(
    book: KomgaBookRecord,
    browseOpts: ReadListBookBrowseOptions
  ) -> Bool {
    if let deletedState = browseOpts.deletedFilter.effectiveBool {
      if book.deleted != deletedState { return false }
    }

    if let oneshotState = browseOpts.oneshotFilter.effectiveBool {
      if book.oneshot != oneshotState { return false }
    }

    let status: ReadStatus
    if let completed = book.progressCompleted, completed {
      status = .read
    } else if book.progressReadDate != nil {
      status = .inProgress
    } else {
      status = .unread
    }

    if !browseOpts.includeReadStatuses.isEmpty {
      if !browseOpts.includeReadStatuses.contains(status) { return false }
    }

    if !browseOpts.excludeReadStatuses.isEmpty {
      if browseOpts.excludeReadStatuses.contains(status) { return false }
    }

    return true
  }

  nonisolated private static func compareOptionalDate(_ lhs: Date?, _ rhs: Date?, ascending: Bool) -> Bool {
    switch (lhs, rhs) {
    case (let l?, let r?):
      return ascending ? (l < r) : (l > r)
    case (nil, nil):
      return false
    case (nil, _):
      return !ascending
    case (_, nil):
      return ascending
    }
  }

  nonisolated private static func compareOptionalStringDate(_ lhs: String?, _ rhs: String?, ascending: Bool) -> Bool {
    switch (lhs, rhs) {
    case (let l?, let r?):
      let order = l.localizedStandardCompare(r)
      return ascending ? order == .orderedAscending : order == .orderedDescending
    case (nil, nil):
      return false
    case (nil, _):
      return !ascending
    case (_, nil):
      return ascending
    }
  }

  nonisolated private static func paginate<T>(_ values: [T], page: Int, size: Int) -> ArraySlice<T> {
    let offset = page * size
    return paginate(values, offset: offset, limit: size)
  }

  nonisolated private static func paginate<T>(_ values: [T], offset: Int, limit: Int) -> ArraySlice<T> {
    guard offset < values.count else { return [] }
    let end = min(offset + limit, values.count)
    return values[offset..<end]
  }

}
