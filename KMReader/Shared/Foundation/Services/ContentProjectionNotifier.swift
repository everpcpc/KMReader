//
// ContentProjectionNotifier.swift
//
//

import Foundation

extension Notification.Name {
  static let bookProjectionDidChange = Notification.Name("BookProjectionDidChange")
  static let seriesProjectionDidChange = Notification.Name("SeriesProjectionDidChange")
}

nonisolated enum ContentProjectionNotifier {
  static func postBookDidChange(bookId: String) async {
    guard !bookId.isEmpty else { return }

    await MainActor.run {
      NotificationCenter.default.post(
        name: .bookProjectionDidChange,
        object: nil,
        userInfo: ["bookId": bookId]
      )
    }
  }

  static func postBooksDidChange(bookIds: [String]) async {
    let ids = Set(bookIds.filter { !$0.isEmpty })
    guard !ids.isEmpty else { return }

    await MainActor.run {
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
  }

  static func postSeriesDidChange(seriesId: String) async {
    guard !seriesId.isEmpty else { return }

    await MainActor.run {
      NotificationCenter.default.post(
        name: .seriesProjectionDidChange,
        object: nil,
        userInfo: ["seriesId": seriesId]
      )
    }
  }

  static func postBookAndSeriesDidChange(bookId: String, seriesId: String? = nil) async {
    await postBookDidChange(bookId: bookId)

    if let seriesId {
      await postSeriesDidChange(seriesId: seriesId)
    } else {
      await postSeriesDidChange(forBookId: bookId)
    }
  }

  static func postSeriesBooksDidChange(seriesId: String) async {
    guard !seriesId.isEmpty else { return }

    let bookIds = await fetchSeriesBookIds(seriesId: seriesId)
    await postBooksDidChange(bookIds: bookIds)
    await postSeriesDidChange(seriesId: seriesId)
  }

  private static func postSeriesDidChange(forBookId bookId: String) async {
    guard
      let database = try? await DatabaseOperator.database(),
      let item = try? await database.fetchBookDisplayItem(
        bookId: bookId,
        instanceId: AppConfig.current.instanceId
      )
    else { return }

    await postSeriesDidChange(seriesId: item.book.seriesId)
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
}
