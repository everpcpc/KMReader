//
//  LiveActivityManager.swift
//  KMReader
//
//  Manages Live Activity for download progress display.
//

import Foundation

#if os(iOS)
  import ActivityKit

  /// Manages Live Activity for download progress on iOS
  @MainActor
  final class LiveActivityManager {
    static let shared = LiveActivityManager()

    private let logger = AppLogger(.offline)
    private var currentActivity: Activity<DownloadActivityAttributes>?

    private init() {}

    /// Start or update a download Live Activity
    func startActivity(
      seriesTitle: String, bookInfo: String, totalBooks: Int, pendingCount: Int, failedCount: Int
    ) {
      if resolveActivity() != nil {
        updateActivity(
          seriesTitle: seriesTitle,
          bookInfo: bookInfo,
          progress: 0.0,
          pendingCount: pendingCount,
          failedCount: failedCount
        )
        return
      }

      guard ActivityAuthorizationInfo().areActivitiesEnabled else {
        logger.info("Live Activities are disabled for this app.")
        return
      }

      let attributes = DownloadActivityAttributes(totalBooks: totalBooks)
      let state = DownloadActivityAttributes.ContentState(
        seriesTitle: seriesTitle,
        bookInfo: bookInfo,
        progress: 0.0,
        pendingCount: pendingCount,
        failedCount: failedCount
      )

      do {
        currentActivity = try Activity.request(
          attributes: attributes,
          content: .init(state: state, staleDate: nil),
          pushType: nil
        )
        logger.info("✅ Live Activity started.")
      } catch {
        logger.error("❌ Failed to start Live Activity: \(error)")
      }
    }

    /// Update the current Live Activity with new progress
    func updateActivity(
      seriesTitle: String,
      bookInfo: String,
      progress: Double,
      pendingCount: Int,
      failedCount: Int
    ) {
      guard let activity = resolveActivity() else { return }

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
    }

    /// End the current Live Activity
    func endActivity() {
      guard let activity = resolveActivity() else { return }

      Task {
        await activity.end(nil, dismissalPolicy: .immediate)
      }
      currentActivity = nil
    }

    private func resolveActivity() -> Activity<DownloadActivityAttributes>? {
      if let currentActivity {
        return currentActivity
      }
      if let existing = Activity<DownloadActivityAttributes>.activities.first {
        currentActivity = existing
        return existing
      }
      return nil
    }
  }
#endif
