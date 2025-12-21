//
//  DivinaManifest.swift
//  KMReader
//
//  Created by Komga iOS Client
//

import Foundation

struct DivinaManifest: Decodable {
  let readingOrder: [DivinaManifestResource]
  let toc: [DivinaManifestLink]?
}

struct DivinaManifestResource: Decodable {
  let href: String
  let type: String?
  let width: Int?
  let height: Int?
}

struct DivinaManifestLink: Decodable {
  let title: String?
  let href: String
}
