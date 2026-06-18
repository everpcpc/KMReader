//
// ContentProjectionNotifier.swift
//
//

import Foundation

extension Notification.Name {
  static let bookProjectionDidChange = Notification.Name("BookProjectionDidChange")
  static let seriesProjectionDidChange = Notification.Name("SeriesProjectionDidChange")
  static let collectionProjectionDidChange = Notification.Name("CollectionProjectionDidChange")
  static let readListProjectionDidChange = Notification.Name("ReadListProjectionDidChange")
}

nonisolated enum ContentProjectionNotifier {
  static let localRefreshDelay: UInt64 = 750_000_000
  static let remoteRefreshDelay: UInt64 = 5_000_000_000

  private static let refreshDelayKey = "refreshDelayNanoseconds"

  @MainActor private static var isDeferringForReader = false
  @MainActor private static var deferredBookDelays: [String: UInt64] = [:]
  @MainActor private static var deferredSeriesDelays: [String: UInt64] = [:]
  @MainActor private static var deferredCollectionDelays: [String: UInt64] = [:]
  @MainActor private static var deferredReadListDelays: [String: UInt64] = [:]

  @MainActor
  static func readerDidOpen() {
    isDeferringForReader = true
  }

  @MainActor
  static func readerDidClose() {
    isDeferringForReader = false
    flushDeferredChanges()
  }

  static func refreshDelay(from notification: Notification) -> UInt64 {
    notification.userInfo?[refreshDelayKey] as? UInt64 ?? localRefreshDelay
  }

  static func postBookDidChange(
    bookId: String,
    refreshDelay: UInt64 = localRefreshDelay
  ) async {
    guard !bookId.isEmpty else { return }

    await MainActor.run {
      if isDeferringForReader {
        deferBookIds([bookId], refreshDelay: refreshDelay)
      } else {
        postBooksNow([bookId], refreshDelay: refreshDelay)
      }
    }
  }

  static func postBooksDidChange(
    bookIds: [String],
    refreshDelay: UInt64 = localRefreshDelay
  ) async {
    let ids = Set(bookIds.filter { !$0.isEmpty })
    guard !ids.isEmpty else { return }

    await MainActor.run {
      if isDeferringForReader {
        deferBookIds(ids, refreshDelay: refreshDelay)
      } else {
        postBooksNow(ids, refreshDelay: refreshDelay)
      }
    }
  }

  static func postSeriesDidChange(
    seriesId: String,
    refreshDelay: UInt64 = localRefreshDelay
  ) async {
    guard !seriesId.isEmpty else { return }

    await MainActor.run {
      if isDeferringForReader {
        deferSeriesIds([seriesId], refreshDelay: refreshDelay)
      } else {
        postSeriesNow(seriesId, refreshDelay: refreshDelay)
      }
    }
  }

  static func postCollectionDidChange(
    collectionId: String,
    refreshDelay: UInt64 = localRefreshDelay
  ) async {
    guard !collectionId.isEmpty else { return }

    await MainActor.run {
      if isDeferringForReader {
        deferCollectionIds([collectionId], refreshDelay: refreshDelay)
      } else {
        postCollectionNow(collectionId, refreshDelay: refreshDelay)
      }
    }
  }

  static func postReadListDidChange(
    readListId: String,
    refreshDelay: UInt64 = localRefreshDelay
  ) async {
    guard !readListId.isEmpty else { return }

    await MainActor.run {
      if isDeferringForReader {
        deferReadListIds([readListId], refreshDelay: refreshDelay)
      } else {
        postReadListNow(readListId, refreshDelay: refreshDelay)
      }
    }
  }

  static func postBookAndSeriesDidChange(
    bookId: String,
    seriesId: String? = nil,
    refreshDelay: UInt64 = localRefreshDelay
  ) async {
    await postBookAndSeriesDidChange(
      bookId: bookId,
      instanceId: AppConfig.current.instanceId,
      seriesId: seriesId,
      refreshDelay: refreshDelay
    )
  }

  static func postBookAndSeriesDidChange(
    bookId: String,
    instanceId: String,
    seriesId: String? = nil,
    refreshDelay: UInt64 = localRefreshDelay
  ) async {
    await postBookDidChange(bookId: bookId, refreshDelay: refreshDelay)

    if let seriesId {
      await postSeriesDidChange(seriesId: seriesId, refreshDelay: refreshDelay)
    } else {
      await postSeriesDidChange(
        forBookId: bookId,
        instanceId: instanceId,
        refreshDelay: refreshDelay
      )
    }
  }

  static func postBooksAndSeriesDidChange(
    bookIds: [String],
    instanceId: String,
    refreshDelay: UInt64 = localRefreshDelay
  ) async {
    let ids = Set(bookIds.filter { !$0.isEmpty })
    guard !ids.isEmpty else { return }

    await postBooksDidChange(bookIds: Array(ids), refreshDelay: refreshDelay)
    let seriesIds = await fetchSeriesIds(forBookIds: Array(ids), instanceId: instanceId)
    for seriesId in seriesIds {
      await postSeriesDidChange(seriesId: seriesId, refreshDelay: refreshDelay)
    }
  }

  static func postSeriesBooksDidChange(
    seriesId: String,
    refreshDelay: UInt64 = localRefreshDelay
  ) async {
    guard !seriesId.isEmpty else { return }

    let bookIds = await fetchSeriesBookIds(seriesId: seriesId)
    await postBooksDidChange(bookIds: bookIds, refreshDelay: refreshDelay)
    await postSeriesDidChange(seriesId: seriesId, refreshDelay: refreshDelay)
  }

  private static func postSeriesDidChange(
    forBookId bookId: String,
    instanceId: String,
    refreshDelay: UInt64
  ) async {
    guard let seriesId = await fetchSeriesId(forBookId: bookId, instanceId: instanceId) else {
      return
    }

    await postSeriesDidChange(seriesId: seriesId, refreshDelay: refreshDelay)
  }

  private static func fetchSeriesId(forBookId bookId: String, instanceId: String) async -> String? {
    guard
      let database = try? await DatabaseOperator.database(),
      let item = try? await database.fetchBookDisplayItem(
        bookId: bookId,
        instanceId: instanceId
      )
    else { return nil }

    return item.book.seriesId
  }

  private static func fetchSeriesIds(forBookIds bookIds: [String], instanceId: String) async
    -> Set<String>
  {
    var seriesIds = Set<String>()
    for bookId in Set(bookIds) {
      if let seriesId = await fetchSeriesId(forBookId: bookId, instanceId: instanceId) {
        seriesIds.insert(seriesId)
      }
    }

    return seriesIds
  }

  private static func fetchSeriesBookIds(seriesId: String) async -> [String] {
    guard let database = try? await DatabaseOperator.database() else { return [] }

    let pageSize = 500
    var page = 0
    var ids: [String] = []

    while true {
      let pageIds = await database.fetchSeriesBookIds(
        seriesId: seriesId,
        browseOpts: BookBrowseOptions(),
        page: page,
        size: pageSize
      )
      ids.append(contentsOf: pageIds)

      guard pageIds.count == pageSize else { break }
      page += 1
    }

    return ids
  }

  @MainActor
  private static func flushDeferredChanges() {
    let bookDelays = deferredBookDelays
    let seriesDelays = deferredSeriesDelays
    let collectionDelays = deferredCollectionDelays
    let readListDelays = deferredReadListDelays

    deferredBookDelays.removeAll()
    deferredSeriesDelays.removeAll()
    deferredCollectionDelays.removeAll()
    deferredReadListDelays.removeAll()

    if !bookDelays.isEmpty {
      postBooksNow(Set(bookDelays.keys), refreshDelay: bookDelays.values.max() ?? localRefreshDelay)
    }
    for (seriesId, delay) in seriesDelays {
      postSeriesNow(seriesId, refreshDelay: delay)
    }
    for (collectionId, delay) in collectionDelays {
      postCollectionNow(collectionId, refreshDelay: delay)
    }
    for (readListId, delay) in readListDelays {
      postReadListNow(readListId, refreshDelay: delay)
    }
  }

  @MainActor
  private static func deferBookIds<S: Sequence>(_ ids: S, refreshDelay: UInt64)
  where S.Element == String {
    for id in ids where !id.isEmpty {
      deferredBookDelays[id] = max(deferredBookDelays[id] ?? 0, refreshDelay)
    }
  }

  @MainActor
  private static func deferSeriesIds<S: Sequence>(_ ids: S, refreshDelay: UInt64)
  where S.Element == String {
    for id in ids where !id.isEmpty {
      deferredSeriesDelays[id] = max(deferredSeriesDelays[id] ?? 0, refreshDelay)
    }
  }

  @MainActor
  private static func deferCollectionIds<S: Sequence>(_ ids: S, refreshDelay: UInt64)
  where S.Element == String {
    for id in ids where !id.isEmpty {
      deferredCollectionDelays[id] = max(deferredCollectionDelays[id] ?? 0, refreshDelay)
    }
  }

  @MainActor
  private static func deferReadListIds<S: Sequence>(_ ids: S, refreshDelay: UInt64)
  where S.Element == String {
    for id in ids where !id.isEmpty {
      deferredReadListDelays[id] = max(deferredReadListDelays[id] ?? 0, refreshDelay)
    }
  }

  @MainActor
  private static func postBooksNow(_ ids: Set<String>, refreshDelay: UInt64) {
    var userInfo: [AnyHashable: Any] = [
      "bookIds": ids,
      refreshDelayKey: refreshDelay,
    ]
    if ids.count == 1, let bookId = ids.first {
      userInfo["bookId"] = bookId
    }
    NotificationCenter.default.post(
      name: .bookProjectionDidChange,
      object: nil,
      userInfo: userInfo
    )
  }

  @MainActor
  private static func postSeriesNow(_ seriesId: String, refreshDelay: UInt64) {
    NotificationCenter.default.post(
      name: .seriesProjectionDidChange,
      object: nil,
      userInfo: [
        "seriesId": seriesId,
        refreshDelayKey: refreshDelay,
      ]
    )
  }

  @MainActor
  private static func postCollectionNow(_ collectionId: String, refreshDelay: UInt64) {
    NotificationCenter.default.post(
      name: .collectionProjectionDidChange,
      object: nil,
      userInfo: [
        "collectionId": collectionId,
        refreshDelayKey: refreshDelay,
      ]
    )
  }

  @MainActor
  private static func postReadListNow(_ readListId: String, refreshDelay: UInt64) {
    NotificationCenter.default.post(
      name: .readListProjectionDidChange,
      object: nil,
      userInfo: [
        "readListId": readListId,
        refreshDelayKey: refreshDelay,
      ]
    )
  }
}
