//
// R2Types.swift
//
//

import Foundation

nonisolated struct R2Device: Codable, Equatable, Sendable {
  let id: String
  let name: String
}

nonisolated struct R2Locator: Codable, Equatable, Sendable {
  struct Location: Codable, Equatable, Sendable {
    let fragments: [String]?
    let progression: Float?
    let position: Int?
    let totalProgression: Float?
  }

  struct Text: Codable, Equatable, Sendable {
    let after: String?
    let before: String?
    let highlight: String?
  }

  let href: String
  let type: String
  let title: String?
  let locations: Location?
  let text: Text?
  let koboSpan: String?
}

nonisolated struct R2Progression: Codable, Equatable, Sendable {
  let modified: Date
  let device: R2Device
  let locator: R2Locator
}

nonisolated struct R2Positions: Codable, Equatable, Sendable {
  let positions: [R2Locator]
  let total: Int
}
