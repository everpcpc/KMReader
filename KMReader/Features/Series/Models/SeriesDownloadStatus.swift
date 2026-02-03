//
//  SeriesDownloadStatus.swift
//  KMReader
//
//  Created by Komga iOS Client
//

import Foundation
import SwiftUI

/// Custom status for series download progress.
enum SeriesDownloadStatus: Equatable, Sendable {
  case notDownloaded
  case partiallyDownloaded(downloaded: Int, total: Int)
  case downloaded
  case pending(downloaded: Int, pending: Int, total: Int)

  var label: String {
    switch self {
    case .notDownloaded:
      return String(localized: "status.not_downloaded")
    case .partiallyDownloaded(let downloaded, let total):
      return String(localized: "status.partially_downloaded \(downloaded)/\(total)")
    case .downloaded:
      return String(localized: "status.downloaded")
    case .pending(let downloaded, let pending, let total):
      return String(localized: "status.pending \(downloaded)+\(pending)/\(total)")
    }
  }

  var icon: String {
    switch self {
    case .notDownloaded:
      return "icloud.and.arrow.down"
    case .partiallyDownloaded:
      return "icloud.and.arrow.down.fill"
    case .downloaded:
      return "checkmark.icloud.fill"
    case .pending:
      return "arrow.clockwise.icloud.fill"
    }
  }

  var color: Color {
    switch self {
    case .notDownloaded:
      return .secondary
    case .partiallyDownloaded:
      return .blue
    case .downloaded:
      return .green
    case .pending:
      return .orange
    }
  }

  var isDownloaded: Bool {
    if case .downloaded = self { return true }
    return false
  }

  var isPending: Bool {
    if case .pending = self { return true }
    return false
  }

  var isProminent: Bool {
    switch self {
    case .notDownloaded:
      return true
    default:
      return false
    }
  }
}
