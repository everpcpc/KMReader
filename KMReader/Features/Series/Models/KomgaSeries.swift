//
// KomgaSeries.swift
//

import Foundation
import SwiftData

typealias KomgaSeries = KMReaderSchemaV6.KomgaSeries

extension KomgaSeries {
  var collectionIds: [String] {
    get {
      collectionIdsRaw.flatMap { try? JSONDecoder().decode([String].self, from: $0) } ?? []
    }
    set { collectionIdsRaw = try? JSONEncoder().encode(newValue) }
  }

  var metadata: SeriesMetadata? {
    get { RawCodableStore.decode(SeriesMetadata.self, from: metadataRaw) }
    set { metadataRaw = RawCodableStore.encodeOptional(newValue) }
  }

  var booksMetadata: SeriesBooksMetadata? {
    get { RawCodableStore.decode(SeriesBooksMetadata.self, from: booksMetadataRaw) }
    set { booksMetadataRaw = RawCodableStore.encodeOptional(newValue) }
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

  var hasStartedReading: Bool {
    booksReadCount > 0 || booksInProgressCount > 0
  }

  var isUnread: Bool {
    !hasStartedReading
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

  func updateMetadata(_ metadata: SeriesMetadata, raw: Data?) {
    metadataRaw = raw ?? RawCodableStore.encode(metadata)
    syncMetadataFields(metadata)
  }

  func updateBooksMetadata(_ booksMetadata: SeriesBooksMetadata, raw: Data?) {
    booksMetadataRaw = raw ?? RawCodableStore.encode(booksMetadata)
    syncBooksMetadataFields(booksMetadata)
  }

  func applyContent(metadata: SeriesMetadata, booksMetadata: SeriesBooksMetadata) {
    updateMetadata(metadata, raw: RawCodableStore.encode(metadata))
    updateBooksMetadata(booksMetadata, raw: RawCodableStore.encode(booksMetadata))
  }

  private func syncMetadataFields(_ metadata: SeriesMetadata) {
    metaTitle = metadata.title
    metaTitleSort = metadata.titleSort

    metaPublisherIndex = MetadataIndex.encode(value: metadata.publisher)
    metaGenresIndex = MetadataIndex.encode(values: metadata.genres ?? [])
    metaTagsIndex = MetadataIndex.encode(values: metadata.tags ?? [])
    metaLanguageIndex = MetadataIndex.encode(value: metadata.language)
  }

  private func syncBooksMetadataFields(_ booksMetadata: SeriesBooksMetadata) {
    metaAuthorsIndex = MetadataIndex.encode(values: booksMetadata.authors?.map(\.name) ?? [])
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
