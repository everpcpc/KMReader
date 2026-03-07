//
// Collection.swift
//
//

import Foundation

nonisolated struct SeriesCollection: Codable, Identifiable, Equatable, Sendable {
  let id: String
  let name: String
  let ordered: Bool
  let seriesIds: [String]
  let createdDate: Date
  let lastModifiedDate: Date
  let filtered: Bool
}
