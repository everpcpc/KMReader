//
// KomgaSeriesRecord.swift
//
//

import Foundation
import SQLiteData

@Table("komga_series")
nonisolated struct KomgaSeriesRecord: Identifiable, Hashable, Sendable {
  let id: String

  // API identifiers.
  var seriesId: String
  var libraryId: String
  var instanceId: String

  // API scalar fields.
  var name: String
  var url: String
  @Column(as: Date.UnixTimeRepresentation.self)
  var created: Date
  @Column(as: Date.UnixTimeRepresentation.self)
  var lastModified: Date

  var booksCount: Int
  var booksReadCount: Int
  var booksUnreadCount: Int
  var booksInProgressCount: Int
  var deleted: Bool = false
  var oneshot: Bool

  // API-aligned payloads
  var metadataRaw: Data?
  var booksMetadataRaw: Data?

  // Query-only projections for filtering/sorting. UI must read from decoded API payloads.
  var metaStatus: String?
  var metaTitle: String
  var metaTitleSort: String
  var booksMetaReleaseDate: String?

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
    oneshot: Bool
  ) {
    self.id = id ?? UUID().uuidString
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

    self.metadataRaw = nil
    self.booksMetadataRaw = nil
    self.metaStatus = nil
    self.metaTitle = ""
    self.metaTitleSort = ""
    self.booksMetaReleaseDate = nil

    self.deleted = deleted
    self.oneshot = oneshot

    setMetadata(metadata)
    setBooksMetadata(booksMetadata)
  }

  mutating func setMetadata(_ metadata: SeriesMetadata) {
    metadataRaw = try? JSONEncoder().encode(metadata)
    metaStatus = metadata.status
    metaTitle = metadata.title
    metaTitleSort = metadata.titleSort
  }

  mutating func setBooksMetadata(_ booksMetadata: SeriesBooksMetadata) {
    booksMetadataRaw = try? JSONEncoder().encode(booksMetadata)
    booksMetaReleaseDate = booksMetadata.releaseDate
  }

  var metadata: SeriesMetadata {
    if let metadataRaw, let decoded = try? JSONDecoder().decode(SeriesMetadata.self, from: metadataRaw) {
      return decoded
    }

    return SeriesMetadata(
      status: metaStatus,
      statusLock: nil,
      created: nil,
      lastModified: nil,
      title: metaTitle,
      titleLock: nil,
      titleSort: metaTitleSort,
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
  }

  var booksMetadata: SeriesBooksMetadata {
    if let booksMetadataRaw, let decoded = try? JSONDecoder().decode(SeriesBooksMetadata.self, from: booksMetadataRaw) {
      return decoded
    }

    return SeriesBooksMetadata(
      created: nil,
      lastModified: nil,
      authors: nil,
      tags: nil,
      releaseDate: booksMetaReleaseDate,
      summary: nil,
      summaryNumber: nil
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
      deleted: deleted,
      oneshot: oneshot
    )
  }

  func toKomgaSeries(localState: KomgaSeriesLocalStateRecord? = nil) -> KomgaSeries {
    let state = localState ?? .empty(instanceId: instanceId, seriesId: seriesId)
    let legacy = KomgaSeries(
      id: id,
      seriesId: seriesId,
      libraryId: libraryId,
      instanceId: instanceId,
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
      isUnavailable: deleted,
      oneshot: oneshot,
      downloadedBooks: state.downloadedBooks,
      pendingBooks: state.pendingBooks,
      downloadedSize: state.downloadedSize,
      offlinePolicy: state.offlinePolicy,
      offlinePolicyLimit: state.offlinePolicyLimit
    )
    legacy.downloadStatusRaw = state.downloadStatusRaw
    legacy.downloadError = state.downloadError
    legacy.downloadAt = state.downloadAt
    legacy.collectionIds = state.collectionIds
    return legacy
  }
}
