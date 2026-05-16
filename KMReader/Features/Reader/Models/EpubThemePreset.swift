//
// EpubThemePreset.swift
//

import Foundation
import SwiftData

typealias EpubThemePreset = KMReaderSchemaV6.EpubThemePresetV1

extension EpubThemePreset {
  @MainActor
  func getPreferences() -> EpubReaderPreferences? {
    return EpubReaderPreferences(rawValue: preferencesJSON)
  }

  @MainActor
  static func create(
    name: String,
    preferences: EpubReaderPreferences
  ) -> EpubThemePreset {
    return EpubThemePreset(
      name: name,
      preferencesJSON: preferences.rawValue
    )
  }
}
