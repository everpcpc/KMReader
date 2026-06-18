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

  @MainActor private static var isDeferringForReader = false
  @MainActor private static var pendingFlushTask: Task<Void, Never>?
  @MainActor private static var pendingBookDeadlines: [String: Date] = [:]
  @MainActor private static var pendingSeriesDeadlines: [String: Date] = [:]
  @MainActor private static var pendingCollectionDeadlines: [String: Date] = [:]
  @MainActor private static var pendingReadListDeadlines: [String: Date] = [:]

  @MainActor
  static func readerDidOpen() {
    isDeferringForReader = true
    pendingFlushTask?.cancel()
    pendingFlushTask = nil
  }

  @MainActor
  static func readerDidClose() {
    isDeferringForReader = false
    schedulePendingFlush()
  }

  static func postBookDidChange(
    bookId: String,
    refreshDelay: UInt64 = localRefreshDelay
  ) async {
    guard !bookId.isEmpty else { return }

    await MainActor.run {
      enqueueBookIds([bookId], refreshDelay: refreshDelay)
    }
  }

  static func postBooksDidChange(
    bookIds: [String],
    refreshDelay: UInt64 = localRefreshDelay
  ) async {
    let ids = Set(bookIds.filter { !$0.isEmpty })
    guard !ids.isEmpty else { return }

    await MainActor.run {
      enqueueBookIds(ids, refreshDelay: refreshDelay)
    }
  }

  static func postSeriesDidChange(
    seriesId: String,
    refreshDelay: UInt64 = localRefreshDelay
  ) async {
    guard !seriesId.isEmpty else { return }

    await MainActor.run {
      enqueueSeriesIds([seriesId], refreshDelay: refreshDelay)
    }
  }

  static func postCollectionDidChange(
    collectionId: String,
    refreshDelay: UInt64 = localRefreshDelay
  ) async {
    guard !collectionId.isEmpty else { return }

    await MainActor.run {
      enqueueCollectionIds([collectionId], refreshDelay: refreshDelay)
    }
  }

  static func postReadListDidChange(
    readListId: String,
    refreshDelay: UInt64 = localRefreshDelay
  ) async {
    guard !readListId.isEmpty else { return }

    await MainActor.run {
      enqueueReadListIds([readListId], refreshDelay: refreshDelay)
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
  private static func enqueueBookIds<S: Sequence>(_ ids: S, refreshDelay: UInt64)
  where S.Element == String {
    let deadline = deadline(after: refreshDelay)
    for id in ids where !id.isEmpty {
      mergeDeadline(deadline, for: id, into: &pendingBookDeadlines)
    }
    schedulePendingFlush()
  }

  @MainActor
  private static func enqueueSeriesIds<S: Sequence>(_ ids: S, refreshDelay: UInt64)
  where S.Element == String {
    let deadline = deadline(after: refreshDelay)
    for id in ids where !id.isEmpty {
      mergeDeadline(deadline, for: id, into: &pendingSeriesDeadlines)
    }
    schedulePendingFlush()
  }

  @MainActor
  private static func enqueueCollectionIds<S: Sequence>(_ ids: S, refreshDelay: UInt64)
  where S.Element == String {
    let deadline = deadline(after: refreshDelay)
    for id in ids where !id.isEmpty {
      mergeDeadline(deadline, for: id, into: &pendingCollectionDeadlines)
    }
    schedulePendingFlush()
  }

  @MainActor
  private static func enqueueReadListIds<S: Sequence>(_ ids: S, refreshDelay: UInt64)
  where S.Element == String {
    let deadline = deadline(after: refreshDelay)
    for id in ids where !id.isEmpty {
      mergeDeadline(deadline, for: id, into: &pendingReadListDeadlines)
    }
    schedulePendingFlush()
  }

  @MainActor
  private static func schedulePendingFlush() {
    pendingFlushTask?.cancel()
    pendingFlushTask = nil

    guard !isDeferringForReader, let deadline = nextPendingDeadline() else { return }

    let sleepNanoseconds = sleepNanoseconds(until: deadline)
    pendingFlushTask = Task { @MainActor in
      do {
        try await Task.sleep(nanoseconds: sleepNanoseconds)
      } catch {
        return
      }

      guard !Task.isCancelled else { return }
      flushDueChanges()
    }
  }

  @MainActor
  private static func flushDueChanges() {
    pendingFlushTask = nil

    guard !isDeferringForReader else { return }

    let now = Date()
    let bookIds = takeDueIds(from: &pendingBookDeadlines, now: now)
    let seriesIds = takeDueIds(from: &pendingSeriesDeadlines, now: now)
    let collectionIds = takeDueIds(from: &pendingCollectionDeadlines, now: now)
    let readListIds = takeDueIds(from: &pendingReadListDeadlines, now: now)

    if !bookIds.isEmpty {
      postBooksNow(bookIds)
    }
    for seriesId in seriesIds {
      postSeriesNow(seriesId)
    }
    for collectionId in collectionIds {
      postCollectionNow(collectionId)
    }
    for readListId in readListIds {
      postReadListNow(readListId)
    }

    schedulePendingFlush()
  }

  @MainActor
  private static func nextPendingDeadline() -> Date? {
    [
      pendingBookDeadlines.values.min(),
      pendingSeriesDeadlines.values.min(),
      pendingCollectionDeadlines.values.min(),
      pendingReadListDeadlines.values.min(),
    ]
    .compactMap { $0 }
    .min()
  }

  private static func deadline(after refreshDelay: UInt64) -> Date {
    Date().addingTimeInterval(Double(refreshDelay) / 1_000_000_000)
  }

  private static func sleepNanoseconds(until deadline: Date) -> UInt64 {
    let seconds = max(0, deadline.timeIntervalSinceNow)
    return UInt64(seconds * 1_000_000_000)
  }

  private static func mergeDeadline(_ deadline: Date, for id: String, into deadlines: inout [String: Date]) {
    if let existing = deadlines[id] {
      deadlines[id] = max(existing, deadline)
    } else {
      deadlines[id] = deadline
    }
  }

  private static func takeDueIds(from deadlines: inout [String: Date], now: Date) -> Set<String> {
    let ids = deadlines.compactMap { id, deadline in
      deadline <= now ? id : nil
    }
    for id in ids {
      deadlines.removeValue(forKey: id)
    }
    return Set(ids)
  }

  @MainActor
  private static func postBooksNow(_ ids: Set<String>) {
    var userInfo: [AnyHashable: Any] = ["bookIds": ids]
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
  private static func postSeriesNow(_ seriesId: String) {
    NotificationCenter.default.post(
      name: .seriesProjectionDidChange,
      object: nil,
      userInfo: ["seriesId": seriesId]
    )
  }

  @MainActor
  private static func postCollectionNow(_ collectionId: String) {
    NotificationCenter.default.post(
      name: .collectionProjectionDidChange,
      object: nil,
      userInfo: ["collectionId": collectionId]
    )
  }

  @MainActor
  private static func postReadListNow(_ readListId: String) {
    NotificationCenter.default.post(
      name: .readListProjectionDidChange,
      object: nil,
      userInfo: ["readListId": readListId]
    )
  }
}
