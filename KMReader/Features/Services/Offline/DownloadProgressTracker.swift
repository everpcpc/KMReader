//
//  DownloadProgressTracker.swift
//  KMReader
//
//  Created by Komga iOS Client
//

import Foundation

/// Observable class for tracking download progress on MainActor.
/// Used by SettingsOfflineTasksView to display progress percentage.
@MainActor
@Observable
class DownloadProgressTracker {
  static let shared = DownloadProgressTracker()

  /// In-memory progress for UI display (not persisted)
  var progress: [String: Double] = [:]

  private init() {}

  func updateProgress(bookId: String, value: Double) {
    progress[bookId] = value
  }

  func clearProgress(bookId: String) {
    progress.removeValue(forKey: bookId)
  }
}
