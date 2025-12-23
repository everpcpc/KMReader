//
//  LiveActivityManager.swift
//  KMReader
//
//  Manages Live Activity for download progress display.
//

import Foundation

#if canImport(ActivityKit)
  import ActivityKit
#endif

/// Manages Live Activity for download progress on iOS
@MainActor
final class LiveActivityManager {
  static let shared = LiveActivityManager()

  #if canImport(ActivityKit)
    private var currentActivity: Activity<DownloadActivityAttributes>?
  #endif

  private init() {}

  /// Start a new download Live Activity
  func startActivity(seriesTitle: String, bookInfo: String, totalBooks: Int, pendingCount: Int) {
    #if canImport(ActivityKit)
      guard ActivityAuthorizationInfo().areActivitiesEnabled else {
        return
      }

      // End any existing activity first
      endActivity()

      let attributes = DownloadActivityAttributes(totalBooks: totalBooks)
      let state = DownloadActivityAttributes.ContentState(
        seriesTitle: seriesTitle,
        bookInfo: bookInfo,
        progress: 0.0,
        pendingCount: pendingCount,
        failedCount: 0
      )

      do {
        currentActivity = try Activity.request(
          attributes: attributes,
          content: .init(state: state, staleDate: nil),
          pushType: nil
        )
      } catch {
        print("Failed to start Live Activity: \(error)")
      }
    #endif
  }

  /// Update the current Live Activity with new progress
  func updateActivity(
    seriesTitle: String,
    bookInfo: String,
    progress: Double,
    pendingCount: Int,
    failedCount: Int
  ) {
    #if canImport(ActivityKit)
      guard let activity = currentActivity else { return }

      let state = DownloadActivityAttributes.ContentState(
        seriesTitle: seriesTitle,
        bookInfo: bookInfo,
        progress: progress,
        pendingCount: pendingCount,
        failedCount: failedCount
      )

      Task {
        await activity.update(.init(state: state, staleDate: nil))
      }
    #endif
  }

  /// End the current Live Activity
  func endActivity() {
    #if canImport(ActivityKit)
      guard let activity = currentActivity else { return }

      Task {
        await activity.end(nil, dismissalPolicy: .immediate)
      }
      currentActivity = nil
    #endif
  }
}
