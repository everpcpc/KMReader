//
//  LocalNotificationService.swift
//  KMReader
//
//  Manages local system notifications for download status.
//

import Foundation
import UserNotifications

#if !os(tvOS)

  /// Service for displaying local notifications (system notification center)
  @MainActor
  final class LocalNotificationService {
    static let shared = LocalNotificationService()

    private let notificationCenter = UNUserNotificationCenter.current()
    private let downloadProgressId = "offline.download.progress"
    private let downloadFailedId = "offline.download.failed"

    private init() {}

    // MARK: - Permission

    /// Request notification permission
    func requestPermission() async -> Bool {
      do {
        let granted = try await notificationCenter.requestAuthorization(
          options: [.alert, .sound, .badge])
        return granted
      } catch {
        return false
      }
    }

    /// Check if notification is authorized
    func isAuthorized() async -> Bool {
      let settings = await notificationCenter.notificationSettings()
      return settings.authorizationStatus == .authorized
    }

    // MARK: - Download Notifications

    /// Show download progress notification (updates existing or creates new)
    func showDownloadProgress(
      currentBook: String,
      pendingCount: Int,
      failedCount: Int
    ) async {
      guard await isAuthorized() else { return }

      let content = UNMutableNotificationContent()
      content.title = String(localized: "notification.download.title")

      var bodyParts: [String] = []

      // Current book (truncate if too long)
      let displayName = currentBook.count > 25 ? String(currentBook.prefix(22)) + "..." : currentBook
      bodyParts.append(String(localized: "notification.download.current \(displayName)"))

      if pendingCount > 0 {
        bodyParts.append(String(localized: "notification.download.pending \(pendingCount)"))
      }

      if failedCount > 0 {
        bodyParts.append(String(localized: "notification.download.failed \(failedCount)"))
      }

      content.body = bodyParts.joined(separator: "\n")
      content.sound = nil  // Silent for progress updates

      let request = UNNotificationRequest(
        identifier: downloadProgressId,
        content: content,
        trigger: nil  // Show immediately
      )

      try? await notificationCenter.add(request)
    }

    /// Show download failed notification
    func showDownloadFailed(bookName: String, error: String) async {
      guard await isAuthorized() else { return }

      let content = UNMutableNotificationContent()
      content.title = String(localized: "notification.download.failed.title")
      content.body = String(localized: "notification.download.failed.body \(bookName)")
      content.sound = .default

      let request = UNNotificationRequest(
        identifier: "\(downloadFailedId).\(UUID().uuidString)",
        content: content,
        trigger: nil
      )

      try? await notificationCenter.add(request)
    }

    /// Clear all download notifications
    func clearDownloadNotifications() {
      notificationCenter.removeDeliveredNotifications(withIdentifiers: [downloadProgressId])
    }
  }

#endif
