//
// KomgaSeries.swift
//
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

  // API-aligned fields
  var metadata: SeriesMetadata?
  var booksMetadata: SeriesBooksMetadata?

  // Query fields
  var metaTitle: String
  var metaTitleSort: String
  var metaPublisherIndex: String = "|"
  var metaAuthorsIndex: String = "|"
  var metaGenresIndex: String = "|"
  var metaTagsIndex: String = "|"
  var metaLanguageIndex: String = "|"

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

    self.metadata = metadata
    self.booksMetadata = booksMetadata
    self.metaTitle = metadata.title
    self.metaTitleSort = metadata.titleSort

    self.isUnavailable = isUnavailable
    self.oneshot = oneshot
    self.downloadedBooks = downloadedBooks
    self.pendingBooks = pendingBooks
    self.downloadedSize = downloadedSize
    self.offlinePolicyRaw = offlinePolicy.rawValue
    self.offlinePolicyLimit = offlinePolicyLimit
    self.collectionIdsRaw = try? JSONEncoder().encode([] as [String])

    rebuildQueryFields()
  }

  func applyContent(metadata: SeriesMetadata, booksMetadata: SeriesBooksMetadata) {
    self.metadata = metadata
    self.booksMetadata = booksMetadata
    rebuildQueryFields()
  }

  func rebuildQueryFields() {
    let metadata = metadata ?? SeriesMetadata.empty
    let booksMetadata = booksMetadata ?? SeriesBooksMetadata.empty

    metaTitle = metadata.title
    metaTitleSort = metadata.titleSort

    metaPublisherIndex = MetadataIndex.encode(value: metadata.publisher)
    metaAuthorsIndex = MetadataIndex.encode(values: booksMetadata.authors?.map(\.name) ?? [])
    metaGenresIndex = MetadataIndex.encode(values: metadata.genres ?? [])
    metaTagsIndex = MetadataIndex.encode(values: metadata.tags ?? [])
    metaLanguageIndex = MetadataIndex.encode(value: metadata.language)
  }

  func toSeries() -> Series {
    let metadata = metadata ?? SeriesMetadata.empty
    let booksMetadata = booksMetadata ?? SeriesBooksMetadata.empty

    return Series(
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
