//
//  KomgaReadList.swift
//  KMReader
//
//  Created by Komga iOS Client
//

import Foundation
import SwiftData

@Model
final class KomgaReadList {
  @Attribute(.unique) var id: String  // Composite: CompositeID.generate

  var readListId: String
  var instanceId: String

  var name: String
  var summary: String
  var ordered: Bool
  var createdDate: Date
  var lastModifiedDate: Date
  var filtered: Bool

  var bookIds: [String] = []

  // Track offline download status (managed locally, manual only)
  var downloadStatusRaw: String = "notDownloaded"
  var downloadError: String?
  var downloadAt: Date?
  var downloadedSize: Int64 = 0
  var downloadedBooks: Int = 0
  var pendingBooks: Int = 0

  /// Computed property for download status.
  var downloadStatus: SeriesDownloadStatus {
    let downloaded = downloadedBooks
    let pending = pendingBooks
    let total = bookIds.count

    if downloadStatusRaw == "downloaded" || (downloaded == total && total > 0) {
      return .downloaded
    }

    if pending > 0 {
      return .pending(downloaded: downloaded, pending: pending, total: total)
    }

    if downloaded > 0 {
      return .partiallyDownloaded(downloaded: downloaded, total: total)
    }

    return .notDownloaded
  }

  init(
    id: String? = nil,
    readListId: String,
    instanceId: String,
    name: String,
    summary: String,
    ordered: Bool,
    createdDate: Date,
    lastModifiedDate: Date,
    filtered: Bool,
    bookIds: [String] = [],
    downloadedBooks: Int = 0,
    pendingBooks: Int = 0,
    downloadedSize: Int64 = 0
  ) {
    self.id = id ?? CompositeID.generate(instanceId: instanceId, id: readListId)
    self.readListId = readListId
    self.instanceId = instanceId
    self.name = name
    self.summary = summary
    self.ordered = ordered
    self.createdDate = createdDate
    self.lastModifiedDate = lastModifiedDate
    self.filtered = filtered
    self.bookIds = bookIds
    self.downloadedBooks = downloadedBooks
    self.pendingBooks = pendingBooks
    self.downloadedSize = downloadedSize
  }

  func toReadList() -> ReadList {
    ReadList(
      id: readListId,
      name: name,
      summary: summary,
      ordered: ordered,
      bookIds: bookIds,
      createdDate: createdDate,
      lastModifiedDate: lastModifiedDate,
      filtered: filtered
    )
  }
}
