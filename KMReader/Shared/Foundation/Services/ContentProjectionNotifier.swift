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
}
