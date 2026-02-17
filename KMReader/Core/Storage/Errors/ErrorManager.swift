//
//  ErrorManager.swift
//  Komga
//
//  Created by Komga iOS Client
//

import Foundation
import OSLog
import SwiftUI

/// Global error manager for handling and displaying errors across the app
@MainActor
@Observable
class ErrorManager {
  static let shared = ErrorManager()

  var hasAlert: Bool = false
  var currentError: AppError?
  var notifications: [AppNotification] = []

  private let logger = AppLogger(.notification)

  private init() {}

  /// Show an alert for an error
  func alert(error: Error) {
    guard shouldShowError(error) else {
      return
    }

    let message = handleError(error)
    guard !message.isEmpty else {
      return
    }

    logger.error("⚠️ Alert: \(message)")

    let appError = AppError(message: message, underlyingError: error)
    currentError = appError
    hasAlert = true
  }

  /// Show an alert with a message
  func alert(message: String) {
    logger.error("⚠️ Alert: \(message)")
    let appError = AppError(message: message, underlyingError: nil)
    currentError = appError
    hasAlert = true
  }

  /// Dismiss the current error alert
  func vanishError() {
    currentError = nil
    hasAlert = false
  }

  /// Show a notification message (non-blocking)
  func notify(message: String, duration: TimeInterval = 2) {
    logger.info("📢 Notify: \(message)")
    let notification = AppNotification(message: message)
    notifications.append(notification)
    DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
      guard let self = self else { return }
      self.notifications.removeAll { $0.id == notification.id }
    }
  }

  // MARK: - Private Error Handling

  private func handleError(_ error: Error) -> String {
    // Handle APIError
    if let apiError = error as? APIError {
      return apiError.description
    }

    // Handle AppErrorType
    if let appError = error as? AppErrorType {
      return appError.description
    }

    // Convert NSError to AppErrorType and handle
    if let nsError = error as NSError? {
      let appError = AppErrorType.from(nsError)
      return appError.description
    }

    return error.localizedDescription
  }

  private func shouldShowError(_ error: Error) -> Bool {
    // Handle AppErrorType
    if let appError = error as? AppErrorType {
      return appError.shouldShow
    }

    // Handle APIError
    if let apiError = error as? APIError {
      // Silently fail offline errors - user is already aware of being offline
      if case .offline = apiError {
        return false
      }

      if case .networkError(let underlyingError, url: _) = apiError {
        // Check if underlying error is cancelled
        if let appError = underlyingError as? AppErrorType,
          case .networkCancelled = appError
        {
          return false
        }
        if let nsError = underlyingError as NSError?,
          nsError.domain == NSURLErrorDomain,
          nsError.code == NSURLErrorCancelled
        {
          return false
        }
      }
    }

    // Convert NSError to AppErrorType and check
    if let nsError = error as NSError? {
      let appError = AppErrorType.from(nsError)
      return appError.shouldShow
    }

    return true
  }
}

struct AppNotification: Identifiable, Equatable {
  let id: UUID
  let message: String

  init(id: UUID = UUID(), message: String) {
    self.id = id
    self.message = message
  }
}

/// Represents an application error with user-friendly message
struct AppError: Identifiable, CustomStringConvertible {
  let id = UUID()
  let message: String
  let underlyingError: Error?
  let timestamp = Date()

  var description: String {
    message
  }
}
