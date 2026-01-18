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
  @Attribute(.unique) var id: String  // Composite: CompositeID.generate

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
  var metaGenresRaw: Data?
  var metaGenresLock: Bool?
  var metaTagsRaw: Data?
  var metaTagsLock: Bool?
  var metaTotalBookCount: Int?
  var metaTotalBookCountLock: Bool?
  var metaSharingLabelsRaw: Data?
  var metaSharingLabelsLock: Bool?
  var metaLinksRaw: Data?  // JSON encoded [WebLink]
  var metaLinksLock: Bool?
  var metaAlternateTitlesRaw: Data?  // JSON encoded [AlternateTitle]
  var metaAlternateTitlesLock: Bool?

  // Flattened SeriesBooksMetadata
  var booksMetaCreated: String?
  var booksMetaLastModified: String?
  var booksMetaAuthorsRaw: Data?  // JSON encoded [Author]
  var booksMetaTagsRaw: Data?
  var booksMetaReleaseDate: String?
  var booksMetaSummary: String?
  var booksMetaSummaryNumber: String?

  var isUnavailable: Bool = false
  var oneshot: Bool

  // Track offline download status (managed locally)
  var downloadStatusRaw: String = "notDownloaded"
  var downloadError: String?
  var downloadAt: Date?
  var downloadedSize: Int64 = 0
  var downloadedBooks: Int = 0
  var pendingBooks: Int = 0
  var offlinePolicyRaw: String = "manual"
  var offlinePolicyLimit: Int = 0

  // Cached collection IDs containing this series
  var collectionIdsRaw: Data?

  var metaGenres: [String] {
    get { metaGenresRaw.flatMap { try? JSONDecoder().decode([String].self, from: $0) } ?? [] }
    set { metaGenresRaw = try? JSONEncoder().encode(newValue) }
  }

  var metaTags: [String] {
    get { metaTagsRaw.flatMap { try? JSONDecoder().decode([String].self, from: $0) } ?? [] }
    set { metaTagsRaw = try? JSONEncoder().encode(newValue) }
  }

  var metaSharingLabels: [String] {
    get { metaSharingLabelsRaw.flatMap { try? JSONDecoder().decode([String].self, from: $0) } ?? [] }
    set { metaSharingLabelsRaw = try? JSONEncoder().encode(newValue) }
  }

  var booksMetaTags: [String] {
    get { booksMetaTagsRaw.flatMap { try? JSONDecoder().decode([String].self, from: $0) } ?? [] }
    set { booksMetaTagsRaw = try? JSONEncoder().encode(newValue) }
  }

  var collectionIds: [String] {
    get {
      collectionIdsRaw.flatMap { try? JSONDecoder().decode([String].self, from: $0) } ?? []
    }
    set { collectionIdsRaw = try? JSONEncoder().encode(newValue) }
  }

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
    isUnavailable: Bool,
    oneshot: Bool,
    downloadedBooks: Int = 0,
    pendingBooks: Int = 0,
    downloadedSize: Int64 = 0,
    offlinePolicy: SeriesOfflinePolicy = .manual,
    offlinePolicyLimit: Int = 0
  ) {
    self.id = id ?? CompositeID.generate(instanceId: instanceId, id: seriesId)
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
    self.metaGenresRaw = try? JSONEncoder().encode(metadata.genres ?? [])
    self.metaGenresLock = metadata.genresLock
    self.metaTagsRaw = try? JSONEncoder().encode(metadata.tags ?? [])
    self.metaTagsLock = metadata.tagsLock
    self.metaTotalBookCount = metadata.totalBookCount
    self.metaTotalBookCountLock = metadata.totalBookCountLock
    self.metaSharingLabelsRaw = try? JSONEncoder().encode(metadata.sharingLabels ?? [])
    self.metaSharingLabelsLock = metadata.sharingLabelsLock
    self.metaLinksRaw = try? JSONEncoder().encode(metadata.links)
    self.metaLinksLock = metadata.linksLock
    self.metaAlternateTitlesRaw = try? JSONEncoder().encode(metadata.alternateTitles)
    self.metaAlternateTitlesLock = metadata.alternateTitlesLock

    // SeriesBooksMetadata
    self.booksMetaCreated = booksMetadata.created
    self.booksMetaLastModified = booksMetadata.lastModified
    self.booksMetaAuthorsRaw = try? JSONEncoder().encode(booksMetadata.authors)
    self.booksMetaTagsRaw = try? JSONEncoder().encode(booksMetadata.tags ?? [])
    self.booksMetaReleaseDate = booksMetadata.releaseDate
    self.booksMetaSummary = booksMetadata.summary
    self.booksMetaSummaryNumber = booksMetadata.summaryNumber

    self.isUnavailable = isUnavailable
    self.oneshot = oneshot
    self.downloadedBooks = downloadedBooks
    self.pendingBooks = pendingBooks
    self.downloadedSize = downloadedSize
    self.offlinePolicyRaw = offlinePolicy.rawValue
    self.offlinePolicyLimit = offlinePolicyLimit
    self.collectionIdsRaw = try? JSONEncoder().encode([] as [String])
  }

  var metadata: SeriesMetadata {
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

  var booksMetadata: SeriesBooksMetadata {
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
      deleted: isUnavailable,
      oneshot: oneshot
    )
  }
}
