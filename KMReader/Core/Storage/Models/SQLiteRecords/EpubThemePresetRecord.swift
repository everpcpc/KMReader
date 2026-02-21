//
// EpubThemePresetRecord.swift
//
//

import Foundation
import SQLiteData

@Table("epub_theme_presets")
nonisolated struct EpubThemePresetRecord: Identifiable, Hashable, Sendable {
  let id: UUID
  var name: String
  var preferencesJSON: String
  @Column(as: Date.UnixTimeRepresentation.self)
  var createdAt: Date
  @Column(as: Date.UnixTimeRepresentation.self)
  var updatedAt: Date
}
