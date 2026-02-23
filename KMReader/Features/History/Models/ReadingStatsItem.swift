//
// ReadingStatsItem.swift
//
//

import Foundation

nonisolated struct ReadingStatsItem: Codable, Equatable, Sendable, Identifiable {
  let name: String
  let value: Double

  var id: String {
    name
  }

  init(name: String, value: Double) {
    self.name = name
    self.value = value
  }

  private enum CodingKeys: String, CodingKey {
    case name
    case label
    case title
    case key
    case value
    case count
    case weight
    case hours
    case total
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    name = try container.decodeFirstString(forKeys: [.name, .label, .title, .key]) ?? "-"
    value = try container.decodeFirstDouble(forKeys: [.value, .count, .weight, .hours, .total]) ?? 0
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(name, forKey: .name)
    try container.encode(value, forKey: .value)
  }
}
