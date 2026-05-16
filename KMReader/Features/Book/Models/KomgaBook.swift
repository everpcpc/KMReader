//
// KomgaBook.swift
//

import Foundation
import SwiftData

typealias KomgaBook = KMReaderSchemaV6.KomgaBook

extension KomgaBook {
  var readListIds: [String] {
    get { readListIdsRaw.flatMap { try? JSONDecoder().decode([String].self, from: $0) } ?? [] }
    set { readListIdsRaw = try? JSONEncoder().encode(newValue) }
  }

  var isolatePages: [Int] {
    get { isolatePagesRaw.flatMap { try? JSONDecoder().decode([Int].self, from: $0) } ?? [] }
    set { isolatePagesRaw = try? JSONEncoder().encode(newValue) }
  }

  /// Page rotations stored as [pageIndex: degrees]
  var pageRotations: [Int: Int] {
    get { pageRotationsRaw.flatMap { try? JSONDecoder().decode([Int: Int].self, from: $0) } ?? [:] }
    set { pageRotationsRaw = try? JSONEncoder().encode(newValue) }
  }

  var epubPreferences: EpubReaderPreferences? {
    get { epubPreferencesRaw.flatMap { EpubReaderPreferences(rawValue: $0) } }
    set { epubPreferencesRaw = newValue?.rawValue }
  }

  var media: Media? {
    get { RawCodableStore.decode(Media.self, from: mediaRaw) }
    set { mediaRaw = RawCodableStore.encodeOptional(newValue) }
  }

  var metadata: BookMetadata? {
    get { RawCodableStore.decode(BookMetadata.self, from: metadataRaw) }
    set { metadataRaw = RawCodableStore.encodeOptional(newValue) }
  }

  var readProgress: ReadProgress? {
    get { RawCodableStore.decode(ReadProgress.self, from: readProgressRaw) }
    set { readProgressRaw = RawCodableStore.encodeOptional(newValue) }
  }

  /// Computed property for download status.
  var downloadStatus: DownloadStatus {
    get {
      switch downloadStatusRaw {
      case "pending":
        return .pending
      case "downloaded":
        return .downloaded
      case "failed":
        return .failed(error: downloadError ?? "Unknown error")
      default:
        return .notDownloaded
      }
    }
    set {
      switch newValue {
      case .notDownloaded:
        downloadStatusRaw = "notDownloaded"
        downloadError = nil
        downloadAt = nil
      case .pending:
        downloadStatusRaw = "pending"
        downloadError = nil
      case .downloaded:
        downloadStatusRaw = "downloaded"
        downloadError = nil
      case .failed(let error):
        downloadStatusRaw = "failed"
        downloadError = error
      }
    }
  }

  var hasStartedReading: Bool {
    readProgress != nil
  }

  var isUnread: Bool {
    !hasStartedReading
  }

  var isCompleted: Bool {
    progressCompleted == true
  }

  var isInProgress: Bool {
    hasStartedReading && !isCompleted
  }

  func updateMedia(_ media: Media, raw: Data?) {
    mediaRaw = raw ?? RawCodableStore.encode(media)
    syncMediaFields(media)
  }

  func updateMetadata(_ metadata: BookMetadata, raw: Data?) {
    metadataRaw = raw ?? RawCodableStore.encode(metadata)
    syncMetadataFields(metadata)
  }

  func applyContent(media: Media, metadata: BookMetadata, readProgress: ReadProgress?) {
    updateMedia(media, raw: RawCodableStore.encode(media))
    updateMetadata(metadata, raw: RawCodableStore.encode(metadata))
    updateReadProgress(readProgress, raw: RawCodableStore.encodeOptional(readProgress))
  }

  func updateReadProgress(_ readProgress: ReadProgress?) {
    updateReadProgress(readProgress, raw: RawCodableStore.encodeOptional(readProgress))
  }

  func updateReadProgress(_ readProgress: ReadProgress?, raw: Data?) {
    readProgressRaw = raw
    syncReadProgressFields(readProgress)
  }

  private func syncMediaFields(_ media: Media) {
    mediaPagesCount = media.pagesCount
    mediaProfile = media.mediaProfile
  }

  private func syncMetadataFields(_ metadata: BookMetadata) {
    metaTitle = metadata.title
    metaNumber = metadata.number
    metaNumberSort = metadata.numberSort
    metaReleaseDate = metadata.releaseDate
    metaAuthorsIndex = MetadataIndex.encode(values: metadata.authors?.map(\.name) ?? [])
    metaTagsIndex = MetadataIndex.encode(values: metadata.tags ?? [])

  }

  private func syncReadProgressFields(_ readProgress: ReadProgress?) {
    progressPage = readProgress?.page
    progressCompleted = readProgress?.completed
    progressReadDate = readProgress?.readDate
  }

  func toBook() -> Book {
    let media = media ?? Media.empty
    let metadata = metadata ?? BookMetadata.empty

    return Book(
      id: bookId,
      seriesId: seriesId,
      seriesTitle: seriesTitle,
      libraryId: libraryId,
      name: name,
      url: url,
      number: number,
      created: created,
      lastModified: lastModified,
      sizeBytes: sizeBytes,
      size: size,
      media: media,
      metadata: metadata,
      readProgress: readProgress,
      deleted: isUnavailable,
      fileHash: nil,
      oneshot: oneshot
    )
  }

  var pages: [BookPage]? {
    get {
      pagesRaw.flatMap { try? JSONDecoder().decode([BookPage].self, from: $0) }
    }
    set {
      pagesRaw = try? JSONEncoder().encode(newValue)
    }
  }

  var tableOfContents: [ReaderTOCEntry]? {
    get {
      tocRaw.flatMap { try? JSONDecoder().decode([ReaderTOCEntry].self, from: $0) }
    }
    set {
      tocRaw = try? JSONEncoder().encode(newValue)
    }
  }
}
