//
//  SeriesMetadataUpdate.swift
//  KMReader
//
//  Created by Komga iOS Client
//

import Foundation

struct SeriesMetadataUpdate: Codable {
  var title: String
  var titleLock: Bool
  var titleSort: String
  var titleSortLock: Bool
  var summary: String
  var summaryLock: Bool
  var publisher: String
  var publisherLock: Bool
  var ageRating: String
  var ageRatingLock: Bool
  var totalBookCount: String
  var totalBookCountLock: Bool
  var language: String
  var languageLock: Bool
  var readingDirection: ReadingDirection
  var readingDirectionLock: Bool
  var status: SeriesStatus
  var statusLock: Bool
  var genres: [String]
  var genresLock: Bool
  var tags: [String]
  var tagsLock: Bool
  var links: [WebLink]
  var linksLock: Bool
  var alternateTitles: [AlternateTitle]
  var alternateTitlesLock: Bool
  var sharingLabels: [String]
  var sharingLabelsLock: Bool

  static func from(_ series: Series) -> SeriesMetadataUpdate {
    SeriesMetadataUpdate(
      title: series.metadata.title,
      titleLock: series.metadata.titleLock ?? false,
      titleSort: series.metadata.titleSort,
      titleSortLock: series.metadata.titleSortLock ?? false,
      summary: series.metadata.summary ?? "",
      summaryLock: series.metadata.summaryLock ?? false,
      publisher: series.metadata.publisher ?? "",
      publisherLock: series.metadata.publisherLock ?? false,
      ageRating: series.metadata.ageRating.map { String($0) } ?? "",
      ageRatingLock: series.metadata.ageRatingLock ?? false,
      totalBookCount: series.metadata.totalBookCount.map { String($0) } ?? "",
      totalBookCountLock: series.metadata.totalBookCountLock ?? false,
      language: series.metadata.language ?? "",
      languageLock: series.metadata.languageLock ?? false,
      readingDirection: ReadingDirection.fromString(series.metadata.readingDirection),
      readingDirectionLock: series.metadata.readingDirectionLock ?? false,
      status: SeriesStatus.fromString(series.metadata.status ?? ""),
      statusLock: series.metadata.statusLock ?? false,
      genres: series.metadata.genres ?? [],
      genresLock: series.metadata.genresLock ?? false,
      tags: series.metadata.tags ?? [],
      tagsLock: series.metadata.tagsLock ?? false,
      links: series.metadata.links ?? [],
      linksLock: series.metadata.linksLock ?? false,
      alternateTitles: series.metadata.alternateTitles ?? [],
      alternateTitlesLock: series.metadata.alternateTitlesLock ?? false,
      sharingLabels: series.metadata.sharingLabels ?? [],
      sharingLabelsLock: series.metadata.sharingLabelsLock ?? false
    )
  }

  func toAPIDict(against original: Series) -> [String: Any] {
    var dict: [String: Any] = [:]

    if title != original.metadata.title {
      dict["title"] = title
    }
    dict["titleLock"] = titleLock

    if titleSort != original.metadata.titleSort {
      dict["titleSort"] = titleSort
    }
    dict["titleSortLock"] = titleSortLock

    if summary != (original.metadata.summary ?? "") {
      dict["summary"] = summary.isEmpty ? NSNull() : summary
    }
    dict["summaryLock"] = summaryLock

    if publisher != (original.metadata.publisher ?? "") {
      dict["publisher"] = publisher.isEmpty ? NSNull() : publisher
    }
    dict["publisherLock"] = publisherLock

    if let ageRatingInt = Int(ageRating), ageRatingInt != (original.metadata.ageRating ?? 0) {
      dict["ageRating"] = ageRating.isEmpty ? NSNull() : ageRatingInt
    } else if ageRating.isEmpty && original.metadata.ageRating != nil {
      dict["ageRating"] = NSNull()
    }
    dict["ageRatingLock"] = ageRatingLock

    if let totalBookCountInt = Int(totalBookCount),
      totalBookCountInt != (original.metadata.totalBookCount ?? 0)
    {
      dict["totalBookCount"] = totalBookCountInt
    } else if totalBookCount.isEmpty && original.metadata.totalBookCount != nil {
      dict["totalBookCount"] = NSNull()
    }
    dict["totalBookCountLock"] = totalBookCountLock

    if language != (original.metadata.language ?? "") {
      dict["language"] = language.isEmpty ? NSNull() : language
    }
    dict["languageLock"] = languageLock

    let currentReadingDirection = ReadingDirection.fromString(original.metadata.readingDirection)
    if readingDirection != currentReadingDirection {
      dict["readingDirection"] = readingDirection.rawValue
    }
    dict["readingDirectionLock"] = readingDirectionLock

    let currentStatus = SeriesStatus.fromString(original.metadata.status)
    if status != currentStatus {
      dict["status"] = status.apiValue
    }
    dict["statusLock"] = statusLock

    if genres != (original.metadata.genres ?? []) {
      dict["genres"] = genres
    }
    dict["genresLock"] = genresLock

    if tags != (original.metadata.tags ?? []) {
      dict["tags"] = tags
    }
    dict["tagsLock"] = tagsLock

    if links != (original.metadata.links ?? []) {
      dict["links"] = links.map { ["label": $0.label, "url": $0.url] }
    }
    dict["linksLock"] = linksLock

    if alternateTitles != (original.metadata.alternateTitles ?? []) {
      dict["alternateTitles"] = alternateTitles.map { ["label": $0.label, "title": $0.title] }
    }
    dict["alternateTitlesLock"] = alternateTitlesLock

    if sharingLabels != (original.metadata.sharingLabels ?? []) {
      dict["sharingLabels"] = sharingLabels
    }
    dict["sharingLabelsLock"] = sharingLabelsLock

    return dict
  }
}
