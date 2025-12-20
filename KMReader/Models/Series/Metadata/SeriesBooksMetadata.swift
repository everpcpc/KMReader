//
//  SeriesBooksMetadata.swift
//  Komga
//
//  Created by Komga iOS Client
//

import Foundation

struct SeriesBooksMetadata: Codable, Equatable, Hashable, Sendable {
  let created: String?
  let lastModified: String?
  let authors: [Author]?
  let tags: [String]?
  let releaseDate: String?
  let summary: String?
  let summaryNumber: String?
}
