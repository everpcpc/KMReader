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
  var notifications: [String] = []

  private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "KMReader", category: "ErrorManager")

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

    logger.error("Alert: \(message)")

    let appError = AppError(message: message, underlyingError: error)
    currentError = appError
    hasAlert = true
  }

  /// Show an alert with a message
  func alert(message: String) {
    logger.error("Alert: \(message)")
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
    logger.info("Notify: \(message)")
    notifications.append(message)
    DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
      guard let self = self, !self.notifications.isEmpty else { return }
      self.notifications.removeFirst()
    }
  }

  // MARK: - Private Error Handling

  private func handleError(_ error: Error) -> String {
    logger.error("Error occurred: \(error.localizedDescription)")

    if let apiError = error as? APIError {
      return apiError.description
    }

    // Handle other error types
    if let nsError = error as NSError? {
      switch nsError.domain {
      case NSURLErrorDomain:
        switch nsError.code {
        case NSURLErrorNotConnectedToInternet:
          return "No internet connection. Please check your network settings."
        case NSURLErrorTimedOut:
          return "Request timed out. Please try again later."
        case NSURLErrorCancelled:
          return ""  // Don't show cancelled errors
        default:
          return "Network error: \(error.localizedDescription)"
        }
      default:
        return error.localizedDescription
      }
    }

    return error.localizedDescription
  }

  private func shouldShowError(_ error: Error) -> Bool {
    if let apiError = error as? APIError {
      if case .networkError(let underlyingError, url: _) = apiError {
        if let nsError = underlyingError as NSError?,
          nsError.code == NSURLErrorCancelled
        {
          return false
        }
      }
    }

    if let nsError = error as NSError?,
      nsError.domain == NSURLErrorDomain,
      nsError.code == NSURLErrorCancelled
    {
      return false
    }

    return true
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
