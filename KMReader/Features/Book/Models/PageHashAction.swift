//
// PageHashAction.swift
//
//

import Foundation

enum PageHashAction: String, Codable, CaseIterable, Sendable {
  case deleteAuto = "DELETE_AUTO"
  case deleteManual = "DELETE_MANUAL"
  case ignore = "IGNORE"

  var label: String {
    switch self {
    case .deleteAuto:
      return String(localized: "Auto Delete")
    case .deleteManual:
      return String(localized: "Manual Delete")
    case .ignore:
      return String(localized: "Ignore")
    }
  }
}
