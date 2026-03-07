//
// Series.swift
//
//

import Foundation

struct Series: Codable, Identifiable, Equatable {
  let id: String
  let libraryId: String
  let name: String
  let url: String
  let created: Date
  let lastModified: Date
  let booksCount: Int
  let booksReadCount: Int
  let booksUnreadCount: Int
  let booksInProgressCount: Int
  let metadata: SeriesMetadata
  let booksMetadata: SeriesBooksMetadata
  let deleted: Bool
  let oneshot: Bool

  var unreadCount: Int {
    booksUnreadCount + booksInProgressCount
  }

  var hasStartedReading: Bool {
    booksReadCount > 0 || booksInProgressCount > 0
  }

  var isUnread: Bool {
    !hasStartedReading
  }
}
