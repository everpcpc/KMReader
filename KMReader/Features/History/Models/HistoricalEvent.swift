//
//  HistoricalEvent.swift
//  KMReader
//
//  Created by Komga iOS Client
//

import Foundation

struct HistoricalEvent: Codable, Identifiable, Equatable {
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
