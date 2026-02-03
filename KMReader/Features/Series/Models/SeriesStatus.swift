//
//  SeriesStatus.swift
//  Komga
//
//  Created by Komga iOS Client
//

import Foundation
import SwiftUI

nonisolated enum SeriesStatus: String, CaseIterable, Hashable, Codable {
  case ongoing = "ONGOING"
  case ended = "ENDED"
  case hiatus = "HIATUS"
  case abandoned = "ABANDONED"

  nonisolated static func fromString(_ status: String?) -> SeriesStatus {
    fromAPIValue(status) ?? .ongoing
  }

  nonisolated static func fromAPIValue(_ status: String?) -> SeriesStatus? {
    guard let status else { return nil }
    return SeriesStatus(rawValue: status.uppercased())
  }

  nonisolated var displayName: String {
    switch self {
    case .ongoing:
      return String(localized: "series.status.ongoing")
    case .ended:
      return String(localized: "series.status.ended")
    case .hiatus:
      return String(localized: "series.status.hiatus")
    case .abandoned:
      return String(localized: "series.status.abandoned")
    }
  }

  nonisolated var icon: String {
    switch self {
    case .ongoing:
      return "bolt.circle"
    case .ended:
      return "checkmark.circle"
    case .hiatus:
      return "pause.circle"
    case .abandoned:
      return "exclamationmark.circle"
    }
  }

  nonisolated var apiValue: String {
    rawValue
  }
}
