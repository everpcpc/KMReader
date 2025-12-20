//
//  SeriesMetadata.swift
//  Komga
//
//  Created by Komga iOS Client
//

import Foundation

struct SeriesMetadata: Codable, Equatable, Hashable, Sendable {
  let status: String?
  let statusLock: Bool?
  let created: String?
  let lastModified: String?
  let title: String
  let titleLock: Bool?
  let titleSort: String
  let titleSortLock: Bool?
  let summary: String?
  let summaryLock: Bool?
  let readingDirection: String?
  let readingDirectionLock: Bool?
  let publisher: String?
  let publisherLock: Bool?
  let ageRating: Int?
  let ageRatingLock: Bool?
  let language: String?
  let languageLock: Bool?
  let genres: [String]?
  let genresLock: Bool?
  let tags: [String]?
  let tagsLock: Bool?
  let totalBookCount: Int?
  let totalBookCountLock: Bool?
  let sharingLabels: [String]?
  let sharingLabelsLock: Bool?
  let links: [WebLink]?
  let linksLock: Bool?
  let alternateTitles: [AlternateTitle]?
  let alternateTitlesLock: Bool?
}
