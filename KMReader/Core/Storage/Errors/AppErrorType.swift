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

  // Reader errors
  case noRenderablePages
  case manifestInvalidHref(String)
  case manifestUnsupportedType(String)
  case manifestUnableToDecodeDocument(String)
  case manifestImageTagNotFound(String)

  // Save image errors
  case bookIdEmpty
  case imageNotCached
  case photoLibraryAccessDenied
  case failedToLoadImageData
  case saveImageError(String)

  // Generic
  case unknown(message: String)
  case underlying(Error)

  var description: String {
    switch self {
    case .validationFailed(let message):
      return String(format: String(localized: "error.validationFailed", defaultValue: "Validation failed: %@"), message)
    case .invalidInput(let message):
      return String(format: String(localized: "error.invalidInput", defaultValue: "Invalid input: %@"), message)
    case .missingRequiredData(let message):
      return String(format: String(localized: "error.missingRequiredData", defaultValue: "Missing required data: %@"), message)
    case .fileNotFound(let path):
      return String(format: String(localized: "error.fileNotFound", defaultValue: "File not found: %@"), path)
    case .fileReadError(let path, let reason):
      return String(format: String(localized: "error.fileReadError", defaultValue: "Failed to read file %1$@: %2$@"), path, reason)
    case .fileWriteError(let path, let reason):
      return String(format: String(localized: "error.fileWriteError", defaultValue: "Failed to write file %1$@: %2$@"), path, reason)
    case .invalidFileURL(let url):
      return String(format: String(localized: "error.invalidFileURL", defaultValue: "Invalid file URL: %@"), url)
    case .storageNotConfigured(let message):
      return String(format: String(localized: "error.storageNotConfigured", defaultValue: "Storage not configured: %@"), message)
    case .storageOperationFailed(let message):
      return String(format: String(localized: "error.storageOperationFailed", defaultValue: "Storage operation failed: %@"), message)
    case .dataCorrupted(let message):
      return String(format: String(localized: "error.dataCorrupted", defaultValue: "Data corrupted: %@"), message)
    case .networkUnavailable:
      return String(localized: "error.networkUnavailable", defaultValue: "No internet connection. Please check your network settings.")
    case .networkTimeout:
      return String(localized: "error.networkTimeout", defaultValue: "Request timed out. Please try again later.")
    case .networkCancelled:
      return String(localized: "error.networkCancelled", defaultValue: "Request cancelled")
    case .networkError(let message):
      return String(format: String(localized: "error.networkError", defaultValue: "Network error: %@"), message)
    case .configurationError(let message):
      return String(format: String(localized: "error.configurationError", defaultValue: "Configuration error: %@"), message)
    case .invalidConfiguration(let message):
      return String(format: String(localized: "error.invalidConfiguration", defaultValue: "Invalid configuration: %@"), message)
    case .operationNotAllowed(let message):
      return String(format: String(localized: "error.operationNotAllowed", defaultValue: "Operation not allowed: %@"), message)
    case .resourceNotFound(let message):
      return String(format: String(localized: "error.resourceNotFound", defaultValue: "Resource not found: %@"), message)
    case .operationFailed(let message):
      return String(format: String(localized: "error.operationFailed", defaultValue: "Operation failed: %@"), message)
    case .noRenderablePages:
      return String(localized: "error.noRenderablePages", defaultValue: "No renderable pages")
    case .manifestInvalidHref(let href):
      return String(format: String(localized: "error.manifestInvalidHref", defaultValue: "Invalid manifest href: %@"), href)
    case .manifestUnsupportedType(let type):
      return String(format: String(localized: "error.manifestUnsupportedType", defaultValue: "Unsupported manifest resource type: %@"), type)
    case .manifestUnableToDecodeDocument(let href):
      return String(format: String(localized: "error.manifestUnableToDecodeDocument", defaultValue: "Unable to decode XHTML document: %@"), href)
    case .manifestImageTagNotFound(let href):
      return String(format: String(localized: "error.manifestImageTagNotFound", defaultValue: "No image tag found in XHTML document: %@"), href)
    case .bookIdEmpty:
      return String(localized: "error.bookIdEmpty", defaultValue: "Book ID is empty")
    case .imageNotCached:
      return String(localized: "error.imageNotCached", defaultValue: "Image not cached yet")
    case .photoLibraryAccessDenied:
      return String(localized: "error.photoLibraryAccessDenied", defaultValue: "Photo library access denied")
    case .failedToLoadImageData:
      return String(localized: "error.failedToLoadImageData", defaultValue: "Failed to load image data")
    case .saveImageError(let message):
      return message
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
