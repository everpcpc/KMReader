//
// ReaderPageBorderCropMode.swift
//
//

import Foundation

enum ReaderPageBorderCropMode: String, CaseIterable, Hashable, Sendable {
  case disabled
  case conservative
  case aggressive

  var displayName: String {
    switch self {
    case .disabled:
      return String(localized: "Disabled")
    case .conservative:
      return String(localized: "Conservative", defaultValue: "Conservative")
    case .aggressive:
      return String(localized: "Aggressive", defaultValue: "Aggressive")
    }
  }
}
