//
//  DivinaManifest.swift
//  KMReader
//
//  Created by Komga iOS Client
//

import Foundation

struct DivinaManifest: Codable, Sendable {
  let readingOrder: [DivinaManifestResource]
  let toc: [DivinaManifestLink]?
}

struct DivinaManifestResource: Codable, Sendable {
  let href: String
  let type: String?
  let width: Int?
  let height: Int?
}

struct DivinaManifestLink: Codable, Sendable {
  let title: String?
  let href: String
}
