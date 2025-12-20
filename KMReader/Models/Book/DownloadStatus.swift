//
//  DownloadStatus.swift
//  KMReader
//
//  Created by Komga iOS Client
//

import Foundation
import SwiftUI

/// Status of an offline book download.
enum DownloadStatus: Equatable, Sendable {
  case notDownloaded
  case downloading(progress: Double)
  case downloaded
  case failed(error: String)

  // MARK: - Menu Display

  /// Label for context menu actions.
  var menuLabel: String {
    switch self {
    case .downloaded:
      return String(localized: "Remove Offline")
    case .downloading:
      return String(localized: "Cancel Download")
    case .notDownloaded, .failed:
      return String(localized: "Make Offline")
    }
  }

  /// Icon for context menu and toolbar actions.
  var menuIcon: String {
    switch self {
    case .downloaded:
      return "square.and.arrow.down.badge.xmark"
    case .downloading:
      return "square.and.arrow.down.badge.clock"
    case .notDownloaded:
      return "square.and.arrow.down"
    case .failed:
      return "exclamationmark.triangle"
    }
  }

  /// Color for the status icon.
  var menuColor: Color {
    switch self {
    case .downloaded:
      return .red
    case .downloading:
      return .blue
    case .notDownloaded:
      return .primary
    case .failed:
      return .orange
    }
  }
}
