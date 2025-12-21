//
//  KomgaSeries.swift
//  KMReader
//
//  Created by Komga iOS Client
//

import Foundation
import SwiftData

@Model
final class KomgaSeries {
  @Attribute(.unique) var id: String  // Composite ID: "\(instanceId)_\(seriesId)"

  var seriesId: String
  var libraryId: String
  var instanceId: String

  var name: String
  var url: String
  var created: Date
  var lastModified: Date

  var booksCount: Int
  var booksReadCount: Int
  var booksUnreadCount: Int
  var booksInProgressCount: Int

  // Flattened SeriesMetadata
  var metaStatus: String?
  var metaStatusLock: Bool?
  var metaCreated: String?
  var metaLastModified: String?
  var metaTitle: String
  var metaTitleLock: Bool?
  var metaTitleSort: String
  var metaTitleSortLock: Bool?
  var metaSummary: String?
  var metaSummaryLock: Bool?
  var metaReadingDirection: String?
  var metaReadingDirectionLock: Bool?
  var metaPublisher: String?
  var metaPublisherLock: Bool?
  var metaAgeRating: Int?
  var metaAgeRatingLock: Bool?
  var metaLanguage: String?
  var metaLanguageLock: Bool?
  var metaGenres: [String]?
  var metaGenresLock: Bool?
  var metaTags: [String]?
  var metaTagsLock: Bool?
  var metaTotalBookCount: Int?
  var metaTotalBookCountLock: Bool?
  var metaSharingLabels: [String]?
  var metaSharingLabelsLock: Bool?
  var metaLinksRaw: Data?  // JSON encoded [WebLink]
  var metaLinksLock: Bool?
  var metaAlternateTitlesRaw: Data?  // JSON encoded [AlternateTitle]
  var metaAlternateTitlesLock: Bool?

  // Flattened SeriesBooksMetadata
  var booksMetaCreated: String?
  var booksMetaLastModified: String?
  var booksMetaAuthorsRaw: Data?  // JSON encoded [Author]
  var booksMetaTags: [String]?
  var booksMetaReleaseDate: String?
  var booksMetaSummary: String?
  var booksMetaSummaryNumber: String?

  var deleted: Bool
  var oneshot: Bool

  // Track offline download status (managed locally)
  var downloadStatusRaw: String = "notDownloaded"
  var downloadError: String?
  var downloadAt: Date?
  var downloadedSize: Int64 = 0
  var downloadedBooks: Int = 0
  var pendingBooks: Int = 0
  var offlinePolicyRaw: String = "manual"

  /// Computed property for download status.
  var downloadStatus: SeriesDownloadStatus {
    let raw = downloadStatusRaw
    let downloaded = downloadedBooks
    let pending = pendingBooks
    let total = booksCount

    if raw == "downloaded" || downloaded == total {
      return .downloaded
    }

    if pending > 0 {
      return .pending(downloaded: downloaded, pending: pending, total: total)
    }

    if downloaded > 0 {
      return .partiallyDownloaded(downloaded: downloaded, total: total)
    }

    return .notDownloaded
  }

  /// Computed property for offline policy.
  var offlinePolicy: SeriesOfflinePolicy {
    get {
      SeriesOfflinePolicy(rawValue: offlinePolicyRaw) ?? .manual
    }
    set {
      offlinePolicyRaw = newValue.rawValue
    }
  }


  init(
    id: String? = nil,
    seriesId: String,
    libraryId: String,
    instanceId: String,
    name: String,
    url: String,
    created: Date,
    lastModified: Date,
    booksCount: Int,
    booksReadCount: Int,
    booksUnreadCount: Int,
    booksInProgressCount: Int,
    metadata: SeriesMetadata,
    booksMetadata: SeriesBooksMetadata,
    deleted: Bool,
    oneshot: Bool,
    downloadedBooks: Int = 0,
    pendingBooks: Int = 0,
    downloadedSize: Int64 = 0,
    offlinePolicy: SeriesOfflinePolicy = .manual
  ) {
    self.id = id ?? "\(instanceId)_\(seriesId)"
    self.seriesId = seriesId
    self.libraryId = libraryId
    self.instanceId = instanceId
    self.name = name
    self.url = url
    self.created = created
    self.lastModified = lastModified
    self.booksCount = booksCount
    self.booksReadCount = booksReadCount
    self.booksUnreadCount = booksUnreadCount
    self.booksInProgressCount = booksInProgressCount

    // SeriesMetadata
    self.metaStatus = metadata.status
    self.metaStatusLock = metadata.statusLock
    self.metaCreated = metadata.created
    self.metaLastModified = metadata.lastModified
    self.metaTitle = metadata.title
    self.metaTitleLock = metadata.titleLock
    self.metaTitleSort = metadata.titleSort
    self.metaTitleSortLock = metadata.titleSortLock
    self.metaSummary = metadata.summary
    self.metaSummaryLock = metadata.summaryLock
    self.metaReadingDirection = metadata.readingDirection
    self.metaReadingDirectionLock = metadata.readingDirectionLock
    self.metaPublisher = metadata.publisher
    self.metaPublisherLock = metadata.publisherLock
    self.metaAgeRating = metadata.ageRating
    self.metaAgeRatingLock = metadata.ageRatingLock
    self.metaLanguage = metadata.language
    self.metaLanguageLock = metadata.languageLock
    self.metaGenres = metadata.genres
    self.metaGenresLock = metadata.genresLock
    self.metaTags = metadata.tags
    self.metaTagsLock = metadata.tagsLock
    self.metaTotalBookCount = metadata.totalBookCount
    self.metaTotalBookCountLock = metadata.totalBookCountLock
    self.metaSharingLabels = metadata.sharingLabels
    self.metaSharingLabelsLock = metadata.sharingLabelsLock
    self.metaLinksRaw = try? JSONEncoder().encode(metadata.links)
    self.metaLinksLock = metadata.linksLock
    self.metaAlternateTitlesRaw = try? JSONEncoder().encode(metadata.alternateTitles)
    self.metaAlternateTitlesLock = metadata.alternateTitlesLock

    // SeriesBooksMetadata
    self.booksMetaCreated = booksMetadata.created
    self.booksMetaLastModified = booksMetadata.lastModified
    self.booksMetaAuthorsRaw = try? JSONEncoder().encode(booksMetadata.authors)
    self.booksMetaTags = booksMetadata.tags
    self.booksMetaReleaseDate = booksMetadata.releaseDate
    self.booksMetaSummary = booksMetadata.summary
    self.booksMetaSummaryNumber = booksMetadata.summaryNumber

    self.deleted = deleted
    self.oneshot = oneshot
    self.downloadedBooks = downloadedBooks
    self.pendingBooks = pendingBooks
    self.downloadedSize = downloadedSize
    self.offlinePolicyRaw = offlinePolicy.rawValue
  }

  var metadata: SeriesMetadata {
    get {
      SeriesMetadata(
        status: metaStatus,
        statusLock: metaStatusLock,
        created: metaCreated,
        lastModified: metaLastModified,
        title: metaTitle,
        titleLock: metaTitleLock,
        titleSort: metaTitleSort,
        titleSortLock: metaTitleSortLock,
        summary: metaSummary,
        summaryLock: metaSummaryLock,
        readingDirection: metaReadingDirection,
        readingDirectionLock: metaReadingDirectionLock,
        publisher: metaPublisher,
        publisherLock: metaPublisherLock,
        ageRating: metaAgeRating,
        ageRatingLock: metaAgeRatingLock,
        language: metaLanguage,
        languageLock: metaLanguageLock,
        genres: metaGenres,
        genresLock: metaGenresLock,
        tags: metaTags,
        tagsLock: metaTagsLock,
        totalBookCount: metaTotalBookCount,
        totalBookCountLock: metaTotalBookCountLock,
        sharingLabels: metaSharingLabels,
        sharingLabelsLock: metaSharingLabelsLock,
        links: metaLinksRaw.flatMap { try? JSONDecoder().decode([WebLink].self, from: $0) },
        linksLock: metaLinksLock,
        alternateTitles: metaAlternateTitlesRaw.flatMap {
          try? JSONDecoder().decode([AlternateTitle].self, from: $0)
        },
        alternateTitlesLock: metaAlternateTitlesLock
      )
    }
    set {
      self.metaStatus = newValue.status
      self.metaStatusLock = newValue.statusLock
      self.metaCreated = newValue.created
      self.metaLastModified = newValue.lastModified
      self.metaTitle = newValue.title
      self.metaTitleLock = newValue.titleLock
      self.metaTitleSort = newValue.titleSort
      self.metaTitleSortLock = newValue.titleSortLock
      self.metaSummary = newValue.summary
      self.metaSummaryLock = newValue.summaryLock
      self.metaReadingDirection = newValue.readingDirection
      self.metaReadingDirectionLock = newValue.readingDirectionLock
      self.metaPublisher = newValue.publisher
      self.metaPublisherLock = newValue.publisherLock
      self.metaAgeRating = newValue.ageRating
      self.metaAgeRatingLock = newValue.ageRatingLock
      self.metaLanguage = newValue.language
      self.metaLanguageLock = newValue.languageLock
      self.metaGenres = newValue.genres
      self.metaGenresLock = newValue.genresLock
      self.metaTags = newValue.tags
      self.metaTagsLock = newValue.tagsLock
      self.metaTotalBookCount = newValue.totalBookCount
      self.metaTotalBookCountLock = newValue.totalBookCountLock
      self.metaSharingLabels = newValue.sharingLabels
      self.metaSharingLabelsLock = newValue.sharingLabelsLock
      self.metaLinksRaw = try? JSONEncoder().encode(newValue.links)
      self.metaLinksLock = newValue.linksLock
      self.metaAlternateTitlesRaw = try? JSONEncoder().encode(newValue.alternateTitles)
      self.metaAlternateTitlesLock = newValue.alternateTitlesLock
    }
  }

  var booksMetadata: SeriesBooksMetadata {
    get {
      SeriesBooksMetadata(
        created: booksMetaCreated,
        lastModified: booksMetaLastModified,
        authors: booksMetaAuthorsRaw.flatMap { try? JSONDecoder().decode([Author].self, from: $0) },
        tags: booksMetaTags,
        releaseDate: booksMetaReleaseDate,
        summary: booksMetaSummary,
        summaryNumber: booksMetaSummaryNumber
      )
    }
    set {
      self.booksMetaCreated = newValue.created
      self.booksMetaLastModified = newValue.lastModified
      self.booksMetaAuthorsRaw = try? JSONEncoder().encode(newValue.authors)
      self.booksMetaTags = newValue.tags
      self.booksMetaReleaseDate = newValue.releaseDate
      self.booksMetaSummary = newValue.summary
      self.booksMetaSummaryNumber = newValue.summaryNumber
    }
  }

  func toSeries() -> Series {
    Series(
      id: seriesId,
      libraryId: libraryId,
      name: name,
      url: url,
      created: created,
      lastModified: lastModified,
      booksCount: booksCount,
      booksReadCount: booksReadCount,
      booksUnreadCount: booksUnreadCount,
      booksInProgressCount: booksInProgressCount,
      metadata: metadata,
      booksMetadata: booksMetadata,
      deleted: deleted,
      oneshot: oneshot
    )
  }
}
