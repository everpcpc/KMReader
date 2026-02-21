//
// SeriesContinueReadingResolver.swift
//
//

import Dependencies
import Foundation
import SQLiteData

@MainActor
enum SeriesContinueReadingResolver {
  static func resolve(
    seriesId: String,
    isOffline: Bool
  ) async -> Book? {
    if isOffline {
      return resolveOffline(seriesId: seriesId)
    }
    return await resolveOnline(seriesId: seriesId)
  }

  private static func resolveOnline(seriesId: String) async -> Book? {
    if let inProgress = await fetchLatestOnlineBook(seriesId: seriesId, status: .inProgress) {
      return inProgress
    }

    if let lastRead = await fetchLatestOnlineBook(seriesId: seriesId, status: .read) {
      if let next = try? await BookService.shared.getNextBook(bookId: lastRead.id) {
        return next
      }
      if let unread = await fetchFirstUnreadOnlineBook(seriesId: seriesId) {
        return unread
      }
      return lastRead
    }

    if let unread = await fetchFirstUnreadOnlineBook(seriesId: seriesId) {
      return unread
    }

    return nil
  }

  private static func fetchLatestOnlineBook(seriesId: String, status: ReadStatus) async -> Book? {
    var opts = BookBrowseOptions()
    opts.includeReadStatuses = [status]
    opts.sortField = .dateRead
    opts.sortDirection = .descending

    if let page = try? await BookService.shared.getBooks(
      seriesId: seriesId,
      page: 0,
      size: 1,
      browseOpts: opts
    ) {
      return page.content.first
    }

    return nil
  }

  private static func fetchFirstUnreadOnlineBook(seriesId: String) async -> Book? {
    var opts = BookBrowseOptions()
    opts.includeReadStatuses = [.unread]
    opts.sortField = .series
    opts.sortDirection = .ascending

    if let page = try? await BookService.shared.getBooks(
      seriesId: seriesId,
      page: 0,
      size: 1,
      browseOpts: opts
    ) {
      return page.content.first
    }

    return nil
  }

  private static func resolveOffline(seriesId: String) -> Book? {
    if let inProgress = fetchLatestOfflineBook(seriesId: seriesId, status: .inProgress) {
      return inProgress
    }

    let orderedBooks = fetchOfflineSeriesBooks(seriesId: seriesId)
    guard !orderedBooks.isEmpty else { return nil }

    if let lastRead = fetchLatestOfflineBook(seriesId: seriesId, status: .read) {
      if let index = orderedBooks.firstIndex(where: { $0.bookId == lastRead.id }) {
        let nextIndex = orderedBooks.index(after: index)
        if nextIndex < orderedBooks.endIndex {
          return orderedBooks[nextIndex].toBook()
        }
      }
    }

    if let firstUnread = orderedBooks.first(where: isUnread) {
      return firstUnread.toBook()
    }

    return orderedBooks.first?.toBook()
  }

  private static func fetchLatestOfflineBook(
    seriesId: String,
    status: ReadStatus
  ) -> Book? {
    var opts = BookBrowseOptions()
    opts.includeReadStatuses = [status]
    opts.sortField = .dateRead
    opts.sortDirection = .descending

    return KomgaBookStore.fetchSeriesBooks(
      seriesId: seriesId,
      page: 0,
      size: 1,
      browseOpts: opts
    ).first
  }

  private static func fetchOfflineSeriesBooks(seriesId: String) -> [KomgaBookRecord] {
    let instanceId = AppConfig.current.instanceId
    @Dependency(\.defaultDatabase) var database

    do {
      return try database.read { db in
        try KomgaBookRecord
          .where { $0.seriesId.eq(seriesId) && $0.instanceId.eq(instanceId) }
          .order(by: \.metaNumberSort)
          .fetchAll(db)
      }
    } catch {
      return []
    }
  }

  private static func isUnread(_ book: KomgaBookRecord) -> Bool {
    book.progressReadDate == nil
  }
}
