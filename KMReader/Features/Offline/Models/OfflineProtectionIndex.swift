//
// OfflineProtectionIndex.swift
//
//

import Foundation

nonisolated struct OfflineProtectionIndex: Sendable {
  private let sourcesByBookId: [String: [OfflineProtectionSource]]

  init(
    books: [KomgaBook],
    series: [KomgaSeries],
    readLists: [KomgaReadList],
    readListMemberships: [ReadListBookMembership]? = nil
  ) {
    let booksBySeriesId = Dictionary(grouping: books) { $0.seriesId }
    let booksByBookId = Dictionary(uniqueKeysWithValues: books.map { ($0.bookId, $0) })
    let readListBookIdsByReadListId =
      readListMemberships.map { memberships in
        Dictionary(grouping: memberships) { $0.readListId }
          .mapValues { memberships in
            memberships.sorted { $0.position < $1.position }.map(\.bookId)
          }
      } ?? [:]

    var sourcesByBookId: [String: [OfflineProtectionSource]] = [:]

    for series in series where series.offlinePolicy != .manual {
      let source = OfflineProtectionSource(
        kind: .series,
        sourceId: series.seriesId,
        name: series.name
      )
      let sourceBooks = (booksBySeriesId[series.seriesId] ?? [])
        .filter { !$0.isUnavailable }
        .sorted(by: KomgaBook.seriesOfflinePolicySort)
      Self.append(
        source: source,
        for: Self.protectedBookIds(
          policy: series.offlinePolicy,
          limit: series.offlinePolicyLimit,
          books: sourceBooks
        ),
        to: &sourcesByBookId
      )
    }

    for readList in readLists where readList.offlinePolicy != .manual {
      let source = OfflineProtectionSource(
        kind: .readList,
        sourceId: readList.readListId,
        name: readList.name
      )
      let sourceBookIds =
        readListMemberships == nil
        ? readList.bookIds
        : readListBookIdsByReadListId[readList.readListId] ?? []
      let sourceBooks = sourceBookIds.compactMap { booksByBookId[$0] }.filter { !$0.isUnavailable }
      Self.append(
        source: source,
        for: Self.protectedBookIds(
          policy: readList.offlinePolicy,
          limit: readList.offlinePolicyLimit,
          books: sourceBooks
        ),
        to: &sourcesByBookId
      )
    }

    self.sourcesByBookId = sourcesByBookId.mapValues { sources in
      sources.sorted { lhs, rhs in
        if lhs.kind.rawValue == rhs.kind.rawValue {
          return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
        }
        return lhs.kind.rawValue < rhs.kind.rawValue
      }
    }
  }

  func sources(for book: KomgaBook) -> [OfflineProtectionSource] {
    sourcesByBookId[book.bookId] ?? []
  }

  func isProtected(_ book: KomgaBook) -> Bool {
    !sources(for: book).isEmpty
  }

  private static func append(
    source: OfflineProtectionSource,
    for bookIds: Set<String>,
    to sourcesByBookId: inout [String: [OfflineProtectionSource]]
  ) {
    for bookId in bookIds {
      sourcesByBookId[bookId, default: []].append(source)
    }
  }

  private static func protectedBookIds(
    policy: OfflinePolicy,
    limit: Int,
    books: [KomgaBook]
  ) -> Set<String> {
    switch policy {
    case .manual:
      return []
    case .all:
      return Set(books.map(\.bookId))
    case .unreadOnly:
      let unreadBooks = books.filter { $0.progressCompleted != true }
      let limitValue = max(0, limit)
      if limitValue > 0 {
        return Set(unreadBooks.prefix(limitValue).map(\.bookId))
      }
      return Set(unreadBooks.map(\.bookId))
    }
  }
}
