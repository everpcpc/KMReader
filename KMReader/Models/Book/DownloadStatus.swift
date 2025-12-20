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
      return "trash.circle"
    case .pending:
      return "xmark.circle"
    case .notDownloaded, .failed:
      return "square.and.arrow.down"
    }
  }

  /// Color for the status icon.
  var menuColor: Color {
    switch self {
    case .downloaded, .pending:
      return .red
    case .notDownloaded, .failed:
      return .primary
    }
  }
}
