//
// DivinaManifest.swift
//
//

import Foundation

nonisolated struct DivinaManifest: Codable, Sendable {
  let readingOrder: [DivinaManifestResource]
  let toc: [DivinaManifestLink]?
}

nonisolated struct DivinaManifestResource: Codable, Sendable {
  let href: String
  let type: String?
  let width: Int?
  let height: Int?
}

nonisolated struct DivinaManifestLink: Codable, Sendable {
  let title: String?
  let href: String
  let children: [DivinaManifestLink]?
}
