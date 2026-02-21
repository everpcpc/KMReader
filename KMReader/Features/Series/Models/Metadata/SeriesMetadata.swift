//
// SeriesMetadata.swift
//
//

import Foundation

nonisolated struct SeriesMetadata: Codable, Equatable, Hashable, Sendable {
  static let empty = SeriesMetadata(
    status: nil,
    statusLock: nil,
    created: nil,
    lastModified: nil,
    title: "",
    titleLock: nil,
    titleSort: "",
    titleSortLock: nil,
    summary: nil,
    summaryLock: nil,
    readingDirection: nil,
    readingDirectionLock: nil,
    publisher: nil,
    publisherLock: nil,
    ageRating: nil,
    ageRatingLock: nil,
    language: nil,
    languageLock: nil,
    genres: nil,
    genresLock: nil,
    tags: nil,
    tagsLock: nil,
    totalBookCount: nil,
    totalBookCountLock: nil,
    sharingLabels: nil,
    sharingLabelsLock: nil,
    links: nil,
    linksLock: nil,
    alternateTitles: nil,
    alternateTitlesLock: nil
  )

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
