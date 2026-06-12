//
// SavedFilterDisplayItem.swift
//
//

import Foundation

nonisolated struct SavedFilterDisplayItem: Equatable, Identifiable, Sendable {
  let id: UUID
  let name: String
  let filterType: SavedFilterType
  let filterDataJSON: String
  let updatedAt: Date
}
