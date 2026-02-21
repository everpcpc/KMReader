//
// KomgaBook.swift
//
//

import Foundation
import SwiftData

@Model
final class KomgaBook {
  @Attribute(.unique) var id: String  // Composite: CompositeID.generate

  var bookId: String
  var seriesId: String
  var libraryId: String
  var instanceId: String

  var name: String
  var url: String
  var number: Double
  var created: Date
  var lastModified: Date
  var sizeBytes: Int64
  var size: String

  // API-aligned fields
  var media: Media?
  var metadata: BookMetadata?
  var readProgress: ReadProgress?

  // Query fields
  var mediaPagesCount: Int
  var mediaProfile: String?
  var metaTitle: String
  var metaNumber: String
  var metaNumberSort: Double
  var metaReleaseDate: String?
  var progressPage: Int?
  var progressCompleted: Bool?
  var progressReadDate: Date?
  var metaAuthorsIndex: String = "|"
  var metaTagsIndex: String = "|"

  var isUnavailable: Bool = false
  var oneshot: Bool
  var seriesTitle: String = ""

  // Metadata storage
  var pagesRaw: Data?
  var tocRaw: Data?
  var webPubManifestRaw: Data?
  var epubProgressionRaw: Data?

  // Track offline download status (managed locally)
  var downloadStatusRaw: String = "notDownloaded"
  var downloadError: String?
  var downloadAt: Date?
  var downloadedSize: Int64 = 0

  // Cached read list IDs containing this book
  var readListIdsRaw: Data?

  var isolatePagesRaw: Data?
  var epubPreferencesRaw: String?

  var readListIds: [String] {
    get { readListIdsRaw.flatMap { try? JSONDecoder().decode([String].self, from: $0) } ?? [] }
    set { readListIdsRaw = try? JSONEncoder().encode(newValue) }
  }

  var isolatePages: [Int] {
    get { isolatePagesRaw.flatMap { try? JSONDecoder().decode([Int].self, from: $0) } ?? [] }
    set { isolatePagesRaw = try? JSONEncoder().encode(newValue) }
  }

  var epubPreferences: EpubReaderPreferences? {
    get { epubPreferencesRaw.flatMap { EpubReaderPreferences(rawValue: $0) } }
    set { epubPreferencesRaw = newValue?.rawValue }
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

  init(
    id: String? = nil,
    bookId: String,
    seriesId: String,
    libraryId: String,
    instanceId: String,
    name: String,
    url: String,
    number: Double,
    created: Date,
    lastModified: Date,
    sizeBytes: Int64,
    size: String,
    media: Media,
    metadata: BookMetadata,
    readProgress: ReadProgress?,
    isUnavailable: Bool,
    oneshot: Bool,
    seriesTitle: String = "",
    downloadedSize: Int64 = 0
  ) {
    self.id = id ?? CompositeID.generate(instanceId: instanceId, id: bookId)
    self.bookId = bookId
    self.seriesId = seriesId
    self.libraryId = libraryId
    self.instanceId = instanceId
    self.name = name
    self.url = url
    self.number = number
    self.created = created
    self.lastModified = lastModified
    self.sizeBytes = sizeBytes
    self.size = size

    self.media = media
    self.metadata = metadata
    self.readProgress = readProgress

    self.mediaPagesCount = media.pagesCount
    self.mediaProfile = media.mediaProfile
    self.metaTitle = metadata.title
    self.metaNumber = metadata.number
    self.metaNumberSort = metadata.numberSort
    self.metaReleaseDate = metadata.releaseDate
    self.progressPage = readProgress?.page
    self.progressCompleted = readProgress?.completed
    self.progressReadDate = readProgress?.readDate

    self.seriesTitle = seriesTitle
    self.isUnavailable = isUnavailable
    self.oneshot = oneshot
    self.downloadedSize = downloadedSize
    self.readListIdsRaw = try? JSONEncoder().encode([] as [String])
    self.isolatePagesRaw = try? JSONEncoder().encode([] as [Int])
    self.epubPreferencesRaw = nil
    self.epubProgressionRaw = nil

    rebuildQueryFields()
  }

  func applyContent(media: Media, metadata: BookMetadata, readProgress: ReadProgress?) {
    self.media = media
    self.metadata = metadata
    self.readProgress = readProgress
    rebuildQueryFields()
  }

  func updateReadProgress(_ readProgress: ReadProgress?) {
    self.readProgress = readProgress
    syncReadProgressFields()
  }

  func rebuildQueryFields() {
    let media = media ?? Media.empty
    let metadata = metadata ?? BookMetadata.empty

    mediaPagesCount = media.pagesCount
    mediaProfile = media.mediaProfile

    metaTitle = metadata.title
    metaNumber = metadata.number
    metaNumberSort = metadata.numberSort
    metaReleaseDate = metadata.releaseDate
    metaAuthorsIndex = MetadataIndex.encode(values: metadata.authors?.map(\.name) ?? [])
    metaTagsIndex = MetadataIndex.encode(values: metadata.tags ?? [])

    syncReadProgressFields()
  }

  private func syncReadProgressFields() {
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
