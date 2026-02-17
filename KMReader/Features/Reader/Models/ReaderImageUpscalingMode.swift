//
//  ReaderImageUpscalingMode.swift
//  KMReader
//

import Foundation

enum ReaderImageUpscalingMode: String, CaseIterable, Hashable {
  case disabled
  case auto
  case always

  var displayName: String {
    switch self {
    case .disabled:
      return String(localized: "Disabled")
    case .auto:
      return String(localized: "Auto")
    case .always:
      return String(localized: "Always", defaultValue: "Always")
    }
  }
}
