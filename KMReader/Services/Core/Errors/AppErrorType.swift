//
//  AppErrorType.swift
//  Komga
//
//  Created by Komga iOS Client
//

import Foundation

/// Application-level error type for KMReader
enum AppErrorType: Error, CustomStringConvertible, LocalizedError {
  // Validation errors
  case validationFailed(message: String)
  case invalidInput(message: String)
  case missingRequiredData(message: String)

  // File operations
  case fileNotFound(path: String)
  case fileReadError(path: String, reason: String)
  case fileWriteError(path: String, reason: String)
  case invalidFileURL(url: String)

  // Data storage
  case storageNotConfigured(message: String)
  case storageOperationFailed(message: String)
  case dataCorrupted(message: String)

  // Network (for non-API network errors)
  case networkUnavailable
  case networkTimeout
  case networkCancelled
  case networkError(message: String)

  // Configuration
  case configurationError(message: String)
  case invalidConfiguration(message: String)

  // Business logic
  case operationNotAllowed(message: String)
  case resourceNotFound(message: String)
  case operationFailed(message: String)

  // Generic
  case unknown(message: String)
  case underlying(Error)

  var description: String {
    switch self {
    case .validationFailed(let message):
      return "Validation failed: \(message)"
    case .invalidInput(let message):
      return "Invalid input: \(message)"
    case .missingRequiredData(let message):
      return "Missing required data: \(message)"
    case .fileNotFound(let path):
      return "File not found: \(path)"
    case .fileReadError(let path, let reason):
      return "Failed to read file \(path): \(reason)"
    case .fileWriteError(let path, let reason):
      return "Failed to write file \(path): \(reason)"
    case .invalidFileURL(let url):
      return "Invalid file URL: \(url)"
    case .storageNotConfigured(let message):
      return "Storage not configured: \(message)"
    case .storageOperationFailed(let message):
      return "Storage operation failed: \(message)"
    case .dataCorrupted(let message):
      return "Data corrupted: \(message)"
    case .networkUnavailable:
      return "No internet connection. Please check your network settings."
    case .networkTimeout:
      return "Request timed out. Please try again later."
    case .networkCancelled:
      return "Request cancelled"
    case .networkError(let message):
      return "Network error: \(message)"
    case .configurationError(let message):
      return "Configuration error: \(message)"
    case .invalidConfiguration(let message):
      return "Invalid configuration: \(message)"
    case .operationNotAllowed(let message):
      return "Operation not allowed: \(message)"
    case .resourceNotFound(let message):
      return "Resource not found: \(message)"
    case .operationFailed(let message):
      return "Operation failed: \(message)"
    case .unknown(let message):
      return message
    case .underlying(let error):
      return error.localizedDescription
    }
  }

  var errorDescription: String? {
    description
  }

  var failureReason: String? {
    switch self {
    case .underlying(let error):
      return error.localizedDescription
    default:
      return description
    }
  }

  /// Convert NSError to AppErrorType
  static func from(_ nsError: NSError) -> AppErrorType {
    switch nsError.domain {
    case NSURLErrorDomain:
      switch nsError.code {
      case NSURLErrorNotConnectedToInternet:
        return .networkUnavailable
      case NSURLErrorTimedOut:
        return .networkTimeout
      case NSURLErrorCancelled:
        return .networkCancelled
      default:
        return .networkError(message: nsError.localizedDescription)
      }
    default:
      return .underlying(nsError)
    }
  }

  /// Check if error should be shown to user
  var shouldShow: Bool {
    switch self {
    case .networkCancelled:
      return false
    default:
      return true
    }
  }
}
