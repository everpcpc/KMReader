//
// MetadataFilterDisplayStyle.swift
//
//

import Foundation

enum MetadataFilterDisplayStyle: Sendable {
  case plain
  case language

  func displayName(for value: String) -> String {
    switch self {
    case .plain:
      return value
    case .language:
      return LanguageCodeHelper.displayName(for: value)
    }
  }
}
