//
// OfflineTaskItem.swift
//
//

import Foundation

nonisolated struct OfflineTaskItem: Equatable, Identifiable, Sendable {
  let id: String
  let bookId: String
  let seriesTitle: String
  let metaNumber: String
  let metaTitle: String
  let downloadStatusRaw: String
  let downloadStatus: DownloadStatus

  var isDownloading: Bool {
    downloadStatusRaw == "downloading"
  }

  var isPending: Bool {
    downloadStatusRaw == "pending"
  }

  var isFailed: Bool {
    downloadStatusRaw == "failed"
  }
}
