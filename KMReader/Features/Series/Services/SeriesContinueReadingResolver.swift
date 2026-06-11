//
// SeriesContinueReadingResolver.swift
//
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
    return await SeriesContinueReadingOnlineResolver.resolve(seriesId: seriesId)
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
    book.isUnread
  }
}
