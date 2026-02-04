//
//  DownloadProgressTracker.swift
//  KMReader
//
//  Created by Komga iOS Client
//

import Foundation

/// Observable class for tracking download progress on MainActor.
/// Used by OfflineTasksView to display progress percentage.
@MainActor
@Observable
class DownloadProgressTracker {
  static let shared = DownloadProgressTracker()

  /// In-memory progress for UI display (not persisted)
  var progress: [String: Double] = [:]

  /// Current downloading book name
  var currentBookName: String?

  /// Number of books pending download
  var pendingCount: Int = 0

  /// Number of books that failed download
  var failedCount: Int = 0

  /// Token to force UI refreshes when queue-related state changes
  var queueUpdateToken: UUID = UUID()

  /// Whether a download is currently active
  var isDownloading: Bool {
    currentBookName != nil
  }

  /// Status message for notification display
  var statusMessage: String? {
    guard isDownloading || pendingCount > 0 || failedCount > 0 else { return nil }

    var parts: [String] = []

    if let name = currentBookName {
      // Truncate long names
      let displayName = name.count > 20 ? String(name.prefix(17)) + "..." : name
      parts.append(String(localized: "Downloading: \(displayName)"))
    }

    if pendingCount > 0 {
      parts.append(String(localized: "\(pendingCount) pending"))
    }

    if failedCount > 0 {
      parts.append(String(localized: "\(failedCount) failed"))
    }

    return parts.joined(separator: " | ")
  }

  private init() {}

  func updateProgress(bookId: String, value: Double) {
    progress[bookId] = value
  }

  func clearProgress(bookId: String) {
    progress.removeValue(forKey: bookId)
  }

  func startDownload(bookName: String) {
    currentBookName = bookName
  }

  func finishDownload() {
    currentBookName = nil
  }

  func updateQueueStatus(pending: Int, failed: Int) {
    pendingCount = pending
    failedCount = failed
    queueUpdateToken = UUID()
  }
}
