//
//  R2Types.swift
//  KMReader
//
//  Created by Komga iOS Client
//

import Foundation

struct R2Device: Codable, Equatable {
  let id: String
  let name: String
}

struct R2Locator: Codable, Equatable {
  struct Location: Codable, Equatable {
    let fragments: [String]?
    let progression: Float?
    let position: Int?
    let totalProgression: Float?
  }

  struct Text: Codable, Equatable {
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

struct R2Progression: Codable, Equatable {
  let modified: Date
  let device: R2Device
  let locator: R2Locator
}
