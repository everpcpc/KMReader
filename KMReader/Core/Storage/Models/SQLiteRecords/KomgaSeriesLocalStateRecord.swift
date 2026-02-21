//
// KomgaSeriesLocalStateRecord.swift
//
//

import Foundation
import SQLiteData

@Table("komga_series_local_state")
nonisolated struct KomgaSeriesLocalStateRecord: Identifiable, Hashable, Sendable {
  let id: String
  var instanceId: String
  var seriesId: String

  var downloadStatusRaw: String = "notDownloaded"
  var downloadError: String?
  @Column(as: Date?.UnixTimeRepresentation.self)
  var downloadAt: Date?
  var downloadedSize: Int64 = 0
  var downloadedBooks: Int = 0
  var pendingBooks: Int = 0
  var offlinePolicyRaw: String = "manual"
  var offlinePolicyLimit: Int = 0
  var collectionIdsRaw: Data?

  var collectionIds: [String] {
    get {
      collectionIdsRaw.flatMap { try? JSONDecoder().decode([String].self, from: $0) } ?? []
    }
    set {
      collectionIdsRaw = try? JSONEncoder().encode(newValue)
    }
  }

  var offlinePolicy: SeriesOfflinePolicy {
    get {
      SeriesOfflinePolicy(rawValue: offlinePolicyRaw) ?? .manual
    }
    set {
      offlinePolicyRaw = newValue.rawValue
    }
  }

  func downloadStatus(totalBooks: Int) -> SeriesDownloadStatus {
    let downloaded = downloadedBooks
    let pending = pendingBooks

    if downloadStatusRaw == "downloaded" || downloaded == totalBooks {
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

  static func empty(instanceId: String, seriesId: String) -> KomgaSeriesLocalStateRecord {
    KomgaSeriesLocalStateRecord(
      id: UUID().uuidString,
      instanceId: instanceId,
      seriesId: seriesId,
      downloadStatusRaw: "notDownloaded",
      downloadError: nil,
      downloadAt: nil,
      downloadedSize: 0,
      downloadedBooks: 0,
      pendingBooks: 0,
      offlinePolicyRaw: SeriesOfflinePolicy.manual.rawValue,
      offlinePolicyLimit: 0,
      collectionIdsRaw: try? JSONEncoder().encode([] as [String])
    )
  }
}
