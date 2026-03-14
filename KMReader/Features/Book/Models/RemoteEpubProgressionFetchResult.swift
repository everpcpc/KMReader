//
// RemoteEpubProgressionFetchResult.swift
//
//

import Foundation

enum RemoteEpubProgressionFetchResult {
  case available(R2Progression)
  case missing
  case retryableFailure(any Error)
  case invalidPayload(any Error)

  var shouldPersistAsMissing: Bool {
    switch self {
    case .available, .missing, .invalidPayload:
      return true
    case .retryableFailure:
      return false
    }
  }
}
