//
//  BookMetadata.swift
//  Komga
//
//  Created by Komga iOS Client
//

import Foundation

struct BookMetadata: Codable, Equatable, Hashable, Sendable {
  let created: String?
  let lastModified: String?
  let title: String
  let titleLock: Bool?
  let summary: String?
  let summaryLock: Bool?
  let number: String
  let numberLock: Bool?
  let numberSort: Double
  let numberSortLock: Bool?
  let releaseDate: String?
  let releaseDateLock: Bool?
  let authors: [Author]?
  let authorsLock: Bool?
  let tags: [String]?
  let tagsLock: Bool?
  let isbn: String?
  let isbnLock: Bool?
  let links: [WebLink]?
  let linksLock: Bool?
}
