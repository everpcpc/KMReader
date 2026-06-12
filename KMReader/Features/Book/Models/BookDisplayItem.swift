//
// BookDisplayItem.swift
//
//

import Foundation

nonisolated struct BookDisplayItem: Equatable, Identifiable, Sendable {
  let id: String
  let instanceId: String
  let book: Book
  let downloadStatus: DownloadStatus
  let readListIds: [String]

  init(
    instanceId: String,
    book: Book,
    downloadStatus: DownloadStatus,
    readListIds: [String] = []
  ) {
    id = book.id
    self.instanceId = instanceId
    self.book = book
    self.downloadStatus = downloadStatus
    self.readListIds = readListIds
  }

  var bookId: String {
    book.id
  }

  var seriesId: String {
    book.seriesId
  }

  var seriesTitle: String {
    book.seriesTitle
  }

  var created: Date {
    book.created
  }

  var size: String {
    book.size
  }

  var media: Media {
    book.media
  }

  var mediaPagesCount: Int {
    book.media.pagesCount
  }

  var metaTitle: String {
    book.metadata.title
  }

  var metaNumber: String {
    book.metadata.number
  }

  var metaReleaseDate: String? {
    book.metadata.releaseDate
  }

  var progressPage: Int? {
    book.readProgress?.page
  }

  var progressCompleted: Bool? {
    book.readProgress?.completed
  }

  var completedLastReadText: String? {
    guard isCompleted, let readDate = book.readProgress?.readDate else { return nil }
    return readDate.formatted(.relative(presentation: .named, unitsStyle: .abbreviated))
  }

  var oneshot: Bool {
    book.oneshot
  }

  var isUnavailable: Bool {
    book.deleted
  }

  var isUnread: Bool {
    book.isUnread
  }

  var isCompleted: Bool {
    book.isCompleted
  }

  var isInProgress: Bool {
    book.isInProgress
  }
}
