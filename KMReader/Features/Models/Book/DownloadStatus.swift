//
//  DownloadStatus.swift
//  KMReader
//
//  Created by Komga iOS Client
//

import Foundation
import SwiftUI

/// Status of an offline book download (persisted in SwiftData).
/// Note: Downloading progress is tracked separately in OfflineManager.
enum DownloadStatus: Equatable, Sendable {
  case notDownloaded
  case pending
  case downloaded
  case failed(error: String)

  // MARK: - Display

  var displayLabel: String {
    switch self {
    case .notDownloaded:
      return String(localized: "status.not_downloaded")
    case .pending:
      return String(localized: "status.pending")
    case .downloaded:
      return String(localized: "status.downloaded")
    case .failed(let error):
      return error
    }
  }

  var displayIcon: String {
    switch self {
    case .notDownloaded:
      return "icloud.and.arrow.down"
    case .pending:
      return "arrow.clockwise.icloud.fill"
    case .downloaded:
      return "checkmark.icloud.fill"
    case .failed:
      return "exclamationmark.icloud.fill"
    }
  }

  var displayColor: Color {
    switch self {
    case .notDownloaded:
      return .secondary
    case .pending:
      return .orange
    case .downloaded:
      return .green
    case .failed:
      return .red
    }
  }

  // MARK: - Menu Display

  /// Label for context menu actions.
  var menuLabel: String {
    switch self {
    case .downloaded:
      return String(localized: "Remove Offline")
    case .pending:
      return String(localized: "Cancel Download")
    case .notDownloaded, .failed:
      return String(localized: "Make Offline")
    }
  }

  /// Icon for context menu and toolbar actions.
  var menuIcon: String {
    switch self {
    case .downloaded:
      return "trash"
    case .pending:
      return "xmark.circle"
    case .notDownloaded, .failed:
      return "icloud.and.arrow.down"
    }
  }

  /// Color for the status icon.
  var menuColor: Color {
    switch self {
    case .downloaded, .pending:
      return .red
    case .notDownloaded, .failed:
      return .accentColor
    }
  }

  var isDownloaded: Bool {
    self == .downloaded
  }

  var isPending: Bool {
    self == .pending
  }
}
