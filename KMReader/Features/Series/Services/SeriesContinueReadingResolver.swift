//
//  SeriesContinueReadingResolver.swift
//  KMReader
//
//  Created by Komga iOS Client
//

import Foundation
import SwiftData

@MainActor
enum SeriesContinueReadingResolver {
  static func resolve(
    seriesId: String,
    isOffline: Bool,
    context: ModelContext
  ) async -> Book? {
    if isOffline {
      return resolveOffline(seriesId: seriesId, context: context)
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

  private static func resolveOffline(seriesId: String, context: ModelContext) -> Book? {
    if let inProgress = fetchLatestOfflineBook(seriesId: seriesId, status: .inProgress, context: context) {
      return inProgress
    }

    let orderedBooks = fetchOfflineSeriesBooks(context: context, seriesId: seriesId)
    guard !orderedBooks.isEmpty else { return nil }

    if let lastRead = fetchLatestOfflineBook(seriesId: seriesId, status: .read, context: context) {
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
    status: ReadStatus,
    context: ModelContext
  ) -> Book? {
    var opts = BookBrowseOptions()
    opts.includeReadStatuses = [status]
    opts.sortField = .dateRead
    opts.sortDirection = .descending

    return KomgaBookStore.fetchSeriesBooks(
      context: context,
      seriesId: seriesId,
      page: 0,
      size: 1,
      browseOpts: opts
    ).first
  }

  private static func fetchOfflineSeriesBooks(
    context: ModelContext,
    seriesId: String
  ) -> [KomgaBook] {
    let instanceId = AppConfig.current.instanceId
    let descriptor = FetchDescriptor<KomgaBook>(
      predicate: #Predicate { $0.seriesId == seriesId && $0.instanceId == instanceId },
      sortBy: [SortDescriptor(\KomgaBook.metaNumberSort, order: .forward)]
    )

    return (try? context.fetch(descriptor)) ?? []
  }

  private static func isUnread(_ book: KomgaBook) -> Bool {
    book.progressReadDate == nil
  }
}
