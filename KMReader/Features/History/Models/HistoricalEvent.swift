//
// HistoricalEvent.swift
//
//

import Foundation

nonisolated struct HistoricalEvent: Codable, Identifiable, Equatable, Sendable {
  let id: String
  let type: String
  let timestamp: Date
  let properties: [String: String]
  let seriesId: String?
  let bookId: String?

  private enum CodingKeys: String, CodingKey {
    case id
    case type
    case timestamp
    case properties
    case seriesId
    case bookId
  }
}
