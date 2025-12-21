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
      return localizedError(
        "error.validationFailed",
        defaultValue: "Validation failed: %@",
        arguments: [message])
    case .invalidInput(let message):
      return localizedError(
        "error.invalidInput",
        defaultValue: "Invalid input: %@",
        arguments: [message])
    case .missingRequiredData(let message):
      return localizedError(
        "error.missingRequiredData",
        defaultValue: "Missing required data: %@",
        arguments: [message])
    case .fileNotFound(let path):
      return localizedError(
        "error.fileNotFound",
        defaultValue: "File not found: %@",
        arguments: [path])
    case .fileReadError(let path, let reason):
      return localizedError(
        "error.fileReadError",
        defaultValue: "Failed to read file %1$@: %2$@",
        arguments: [path, reason])
    case .fileWriteError(let path, let reason):
      return localizedError(
        "error.fileWriteError",
        defaultValue: "Failed to write file %1$@: %2$@",
        arguments: [path, reason])
    case .invalidFileURL(let url):
      return localizedError(
        "error.invalidFileURL",
        defaultValue: "Invalid file URL: %@",
        arguments: [url])
    case .storageNotConfigured(let message):
      return localizedError(
        "error.storageNotConfigured",
        defaultValue: "Storage not configured: %@",
        arguments: [message])
    case .storageOperationFailed(let message):
      return localizedError(
        "error.storageOperationFailed",
        defaultValue: "Storage operation failed: %@",
        arguments: [message])
    case .dataCorrupted(let message):
      return localizedError(
        "error.dataCorrupted",
        defaultValue: "Data corrupted: %@",
        arguments: [message])
    case .networkUnavailable:
      return localizedError(
        "error.networkUnavailable",
        defaultValue: "No internet connection. Please check your network settings.")
    case .networkTimeout:
      return localizedError(
        "error.networkTimeout",
        defaultValue: "Request timed out. Please try again later.")
    case .networkCancelled:
      return localizedError("error.networkCancelled", defaultValue: "Request cancelled")
    case .networkError(let message):
      return localizedError(
        "error.networkError",
        defaultValue: "Network error: %@",
        arguments: [message])
    case .configurationError(let message):
      return localizedError(
        "error.configurationError",
        defaultValue: "Configuration error: %@",
        arguments: [message])
    case .invalidConfiguration(let message):
      return localizedError(
        "error.invalidConfiguration",
        defaultValue: "Invalid configuration: %@",
        arguments: [message])
    case .operationNotAllowed(let message):
      return localizedError(
        "error.operationNotAllowed",
        defaultValue: "Operation not allowed: %@",
        arguments: [message])
    case .resourceNotFound(let message):
      return localizedError(
        "error.resourceNotFound",
        defaultValue: "Resource not found: %@",
        arguments: [message])
    case .operationFailed(let message):
      return localizedError(
        "error.operationFailed",
        defaultValue: "Operation failed: %@",
        arguments: [message])
    case .noRenderablePages:
      return localizedError(
        "error.noRenderablePages",
        defaultValue: "No renderable pages")
    case .manifestInvalidHref(let href):
      return localizedError(
        "error.manifestInvalidHref",
        defaultValue: "Invalid manifest href: %@",
        arguments: [href])
    case .manifestUnsupportedType(let type):
      return localizedError(
        "error.manifestUnsupportedType",
        defaultValue: "Unsupported manifest resource type: %@",
        arguments: [type])
    case .manifestUnableToDecodeDocument(let href):
      return localizedError(
        "error.manifestUnableToDecodeDocument",
        defaultValue: "Unable to decode XHTML document: %@",
        arguments: [href])
    case .manifestImageTagNotFound(let href):
      return localizedError(
        "error.manifestImageTagNotFound",
        defaultValue: "No image tag found in XHTML document: %@",
        arguments: [href])
    case .bookIdEmpty:
      return localizedError("error.bookIdEmpty", defaultValue: "Book ID is empty")
    case .imageNotCached:
      return localizedError("error.imageNotCached", defaultValue: "Image not cached yet")
    case .photoLibraryAccessDenied:
      return localizedError(
        "error.photoLibraryAccessDenied",
        defaultValue: "Photo library access denied")
    case .failedToLoadImageData:
      return localizedError(
        "error.failedToLoadImageData",
        defaultValue: "Failed to load image data")
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

private func localizedError(_ key: String, defaultValue: String, arguments: [CVarArg] = [])
  -> String
{
  let format = NSLocalizedString(
    key,
    tableName: nil,
    bundle: .main,
    value: defaultValue,
    comment: ""
  )
  guard !arguments.isEmpty else {
    return format
  }
  return String(format: format, locale: Locale.current, arguments: arguments)
}
