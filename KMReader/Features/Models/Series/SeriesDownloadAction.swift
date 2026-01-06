//
//  SeriesDownloadAction.swift
//  KMReader
//

import Foundation

enum SeriesDownloadAction: String, Identifiable, CaseIterable {
  case download
  case remove
  case cancel

  var id: String { rawValue }

  func label(for status: SeriesDownloadStatus) -> String {
    switch self {
    case .download:
      return status == .notDownloaded
        ? String(localized: "Make Offline") : String(localized: "Download All")
    case .remove:
      return status == .downloaded
        ? String(localized: "Remove Offline") : String(localized: "Remove All")
    case .cancel:
      return String(localized: "Cancel Download")
    }
  }

  func icon(for status: SeriesDownloadStatus) -> String {
    switch self {
    case .download:
      return "icloud.and.arrow.down"
    case .remove:
      return "trash"
    case .cancel:
      return "xmark.circle"
    }
  }

  var isDestructive: Bool {
    switch self {
    case .remove, .cancel:
      return true
    default:
      return false
    }
  }

  var requiresConfirmation: Bool {
    switch self {
    case .download, .remove:
      return true
    case .cancel:
      return false
    }
  }

  func confirmationMessage(for status: SeriesDownloadStatus) -> String {
    switch self {
    case .download:
      return String(localized: "confirm.download_all_books")
    case .remove:
      return String(localized: "confirm.remove_all_offline_books")
    case .cancel:
      return ""
    }
  }

  static func availableActions(for status: SeriesDownloadStatus) -> [SeriesDownloadAction] {
    switch status {
    case .notDownloaded:
      return [.download]
    case .partiallyDownloaded:
      return [.download, .remove]
    case .downloaded:
      return [.remove]
    case .pending:
      return [.cancel]
    }
  }
}
