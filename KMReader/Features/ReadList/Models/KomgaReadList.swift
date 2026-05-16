//
// KomgaReadList.swift
//

import Foundation
import SwiftData

typealias KomgaReadList = KMReaderSchemaV6.KomgaReadList

extension KomgaReadList {
  var bookIds: [String] {
    get { bookIdsRaw.flatMap { try? JSONDecoder().decode([String].self, from: $0) } ?? [] }
    set { bookIdsRaw = try? JSONEncoder().encode(newValue) }
  }

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
