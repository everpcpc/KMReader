//
// DownloadProgressTracker.swift
//
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

  @ObservationIgnored private var lastProgressUpdate: [String: Date] = [:]
  @ObservationIgnored private let progressUpdateInterval: TimeInterval = 1.0
  @ObservationIgnored private let progressUpdateDelta = 0.001

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
    let clampedValue = min(max(value, 0), 1)
    let previousValue = progress[bookId]
    let isTerminalValue = clampedValue == 0 || clampedValue == 1
    let hasMeaningfulDelta = previousValue.map { abs($0 - clampedValue) >= progressUpdateDelta } ?? true

    if !isTerminalValue, !hasMeaningfulDelta {
      return
    }

    let now = Date()
    if !isTerminalValue,
      let lastUpdate = lastProgressUpdate[bookId],
      now.timeIntervalSince(lastUpdate) < progressUpdateInterval
    {
      return
    }

    lastProgressUpdate[bookId] = now
    progress[bookId] = clampedValue
  }

  func clearProgress(bookId: String) {
    progress.removeValue(forKey: bookId)
    lastProgressUpdate.removeValue(forKey: bookId)
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
