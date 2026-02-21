//
// KomgaReadListLocalStateRecord.swift
//
//

import Foundation
import SQLiteData

@Table("komga_read_list_local_state")
nonisolated struct KomgaReadListLocalStateRecord: Identifiable, Hashable, Sendable {
  let id: String
  var instanceId: String
  var readListId: String

  var downloadStatusRaw: String = "notDownloaded"
  var downloadError: String?
  @Column(as: Date?.UnixTimeRepresentation.self)
  var downloadAt: Date?
  var downloadedSize: Int64 = 0
  var downloadedBooks: Int = 0
  var pendingBooks: Int = 0

  func downloadStatus(totalBooks: Int) -> SeriesDownloadStatus {
    let downloaded = downloadedBooks
    let pending = pendingBooks

    if downloadStatusRaw == "downloaded" || (downloaded == totalBooks && totalBooks > 0) {
      return .downloaded
    }

    if pending > 0 {
      return .pending(downloaded: downloaded, pending: pending, total: totalBooks)
    }

    if downloaded > 0 {
      return .partiallyDownloaded(downloaded: downloaded, total: totalBooks)
    }

    return .notDownloaded
  }

  static func empty(instanceId: String, readListId: String) -> KomgaReadListLocalStateRecord {
    KomgaReadListLocalStateRecord(
      id: UUID().uuidString,
      instanceId: instanceId,
      readListId: readListId,
      downloadStatusRaw: "notDownloaded",
      downloadError: nil,
      downloadAt: nil,
      downloadedSize: 0,
      downloadedBooks: 0,
      pendingBooks: 0
    )
  }
}
