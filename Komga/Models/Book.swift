//
//  Book.swift
//  Komga
//
//  Created by Komga iOS Client
//

import Foundation

struct Book: Codable, Identifiable, Equatable {
  let id: String
  let seriesId: String
  let seriesTitle: String
  let libraryId: String
  let name: String
  let url: String
  let number: Double
  let created: Date
  let lastModified: Date
  let sizeBytes: Int64
  let size: String
  let media: Media
  let metadata: BookMetadata
  let readProgress: ReadProgress?
  let deleted: Bool
  let oneshot: Bool
}

struct Media: Codable, Equatable {
  let status: String
  let mediaType: String
  let pagesCount: Int
  let comment: String?
  let mediaProfile: String?
  let epubDivinaCompatible: Bool?
  let epubIsKepub: Bool?
}

struct BookMetadata: Codable, Equatable {
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

struct Author: Codable, Equatable, Hashable {
  let name: String
  let role: String
}

struct WebLink: Codable, Equatable {
  let label: String
  let url: String
}

struct ReadProgress: Codable, Equatable {
  let page: Int
  let completed: Bool
  let readDate: Date
  let created: Date
  let lastModified: Date
}

struct BookPage: Codable, Identifiable {
  let number: Int
  let fileName: String
  let mediaType: String
  let width: Int?
  let height: Int?
  let sizeBytes: Int64?
  let size: String

  var id: Int { number }
}
