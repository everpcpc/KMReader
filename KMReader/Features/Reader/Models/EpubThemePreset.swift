//
// EpubThemePreset.swift
//

import Foundation
import SwiftData

typealias EpubThemePreset = KMReaderSchemaV6.EpubThemePresetV1

extension EpubThemePreset {
  @MainActor
  func getPreferences() -> EpubThemePreferences? {
    return EpubThemePreferences(rawValue: preferencesJSON)
  }

  @MainActor
  static func create(
    name: String,
    preferences: EpubThemePreferences
  ) -> EpubThemePreset {
    return EpubThemePreset(
      name: name,
      preferencesJSON: preferences.rawValue
    )
  }
}
