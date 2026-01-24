//
//  EpubThemePreset.swift
//  KMReader
//
//  Created by Komga iOS Client
//

import Foundation
import SwiftData

typealias EpubThemePreset = EpubThemePresetV1

@Model
final class EpubThemePresetV1 {
  @Attribute(.unique) var id: UUID

  var name: String
  var preferencesJSON: String
  var createdAt: Date
  var updatedAt: Date

  init(
    id: UUID = UUID(),
    name: String,
    preferencesJSON: String,
    createdAt: Date = Date(),
    updatedAt: Date = Date()
  ) {
    self.id = id
    self.name = name
    self.preferencesJSON = preferencesJSON
    self.createdAt = createdAt
    self.updatedAt = updatedAt
  }

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
