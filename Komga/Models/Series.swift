//
//  Series.swift
//  Komga
//
//  Created by Komga iOS Client
//

import Foundation

struct Series: Codable, Identifiable, Equatable {
  let id: String
  let libraryId: String
  let name: String
  let url: String
  let created: Date
  let lastModified: Date
  let booksCount: Int
  let booksReadCount: Int
  let booksUnreadCount: Int
  let booksInProgressCount: Int
  let metadata: SeriesMetadata
  let booksMetadata: SeriesBooksMetadata
  let deleted: Bool
  let oneshot: Bool
}

struct SeriesMetadata: Codable, Equatable {
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

struct SeriesBooksMetadata: Codable, Equatable {
  let created: String?
  let lastModified: String?
  let authors: [Author]?
  let tags: [String]?
  let releaseDate: String?
  let summary: String?
  let summaryNumber: String?
}

struct AlternateTitle: Codable, Equatable {
  let label: String
  let title: String
}
