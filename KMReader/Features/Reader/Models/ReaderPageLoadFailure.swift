//
// ReaderPageLoadFailure.swift
//
//

import Foundation

/// Reason a DIVINA page image failed to load, carried from the load pipeline
/// to the page presentation as a single typed value.
enum ReaderPageLoadFailure: Equatable, Sendable {
  case readDownloadFailed
  case serverError(Int)
  case networkError(String)
  case offlineUnavailable
  case unknown

  var title: String {
    String(localized: "Failed to load page")
  }

  var detail: String? {
    switch self {
    case .readDownloadFailed:
      return String(localized: "Failed to read the downloaded file")
    case .serverError(let code):
      return String(format: String(localized: "Server error (%lld)"), code)
    case .networkError(let message):
      return message
    case .offlineUnavailable:
      return String(localized: "Page not available offline")
    case .unknown:
      return nil
    }
  }
}
