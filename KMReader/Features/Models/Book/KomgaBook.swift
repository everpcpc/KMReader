//
//  KomgaBook.swift
//  KMReader
//
//  Created by Komga iOS Client
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

  // Flattened Media
  var mediaStatus: String
  var mediaType: String
  var mediaPagesCount: Int
  var mediaComment: String?
  var mediaProfile: String?
  var mediaEpubDivinaCompatible: Bool?
  var mediaEpubIsKepub: Bool?

  // Flattened Metadata
  var metaCreated: String?
  var metaLastModified: String?
  var metaTitle: String
  var metaTitleLock: Bool?
  var metaSummary: String?
  var metaSummaryLock: Bool?
  var metaNumber: String
  var metaNumberLock: Bool?
  var metaNumberSort: Double
  var metaNumberSortLock: Bool?
  var metaReleaseDate: String?
  var metaReleaseDateLock: Bool?
  var metaAuthorsRaw: Data?  // JSON encoded [Author]
  var metaAuthorsLock: Bool?
  var metaTagsRaw: Data?  // JSON encoded [String]
  var metaTagsLock: Bool?
  var metaIsbn: String?
  var metaIsbnLock: Bool?
  var metaLinksRaw: Data?  // JSON encoded [WebLink]
  var metaLinksLock: Bool?

  // Flattened ReadProgress
  var progressPage: Int?
  var progressCompleted: Bool?
  var progressReadDate: Date?
  var progressCreated: Date?
  var progressLastModified: Date?

  var isUnavailable: Bool = false
  var oneshot: Bool
  var seriesTitle: String = ""

  // Metadata storage
  var pagesRaw: Data?
  var tocRaw: Data?

  // Track offline download status (managed locally)
  var downloadStatusRaw: String = "notDownloaded"
  var downloadError: String?
  var downloadAt: Date?
  var downloadedSize: Int64 = 0

  // Cached read list IDs containing this book
  var readListIdsRaw: Data?

  var isolatePagesRaw: Data?

  var metaTags: [String] {
    get { metaTagsRaw.flatMap { try? JSONDecoder().decode([String].self, from: $0) } ?? [] }
    set { metaTagsRaw = try? JSONEncoder().encode(newValue) }
  }

  var readListIds: [String] {
    get { readListIdsRaw.flatMap { try? JSONDecoder().decode([String].self, from: $0) } ?? [] }
    set { readListIdsRaw = try? JSONEncoder().encode(newValue) }
  }

  var isolatePages: [Int] {
    get { isolatePagesRaw.flatMap { try? JSONDecoder().decode([Int].self, from: $0) } ?? [] }
    set { isolatePagesRaw = try? JSONEncoder().encode(newValue) }
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
        downloadAt = nil
      case .failed(let error):
        downloadStatusRaw = "failed"
        downloadError = error
        downloadAt = nil
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
    self.seriesTitle = seriesTitle

    // Media
    self.mediaStatus = media.statusRaw
    self.mediaType = media.mediaType
    self.mediaPagesCount = media.pagesCount
    self.mediaComment = media.comment
    self.mediaProfile = media.mediaProfileRaw
    self.mediaEpubDivinaCompatible = media.epubDivinaCompatible
    self.mediaEpubIsKepub = media.epubIsKepub

    // Metadata
    self.metaCreated = metadata.created
    self.metaLastModified = metadata.lastModified
    self.metaTitle = metadata.title
    self.metaTitleLock = metadata.titleLock
    self.metaSummary = metadata.summary
    self.metaSummaryLock = metadata.summaryLock
    self.metaNumber = metadata.number
    self.metaNumberLock = metadata.numberLock
    self.metaNumberSort = metadata.numberSort
    self.metaNumberSortLock = metadata.numberSortLock
    self.metaReleaseDate = metadata.releaseDate
    self.metaReleaseDateLock = metadata.releaseDateLock
    self.metaAuthorsRaw = try? JSONEncoder().encode(metadata.authors)
    self.metaAuthorsLock = metadata.authorsLock
    self.metaTagsRaw = try? JSONEncoder().encode(metadata.tags ?? [])
    self.metaTagsLock = metadata.tagsLock
    self.metaIsbn = metadata.isbn
    self.metaIsbnLock = metadata.isbnLock
    self.metaLinksRaw = try? JSONEncoder().encode(metadata.links)
    self.metaLinksLock = metadata.linksLock

    // ReadProgress
    self.progressPage = readProgress?.page
    self.progressCompleted = readProgress?.completed
    self.progressReadDate = readProgress?.readDate
    self.progressCreated = readProgress?.created
    self.progressLastModified = readProgress?.lastModified

    self.isUnavailable = isUnavailable
    self.oneshot = oneshot
    self.downloadedSize = downloadedSize
    self.readListIdsRaw = try? JSONEncoder().encode([] as [String])
    self.isolatePagesRaw = try? JSONEncoder().encode([] as [Int])
  }

  var media: Media {
    Media(
      status: MediaStatus(rawValue: mediaStatus) ?? .unknown,
      mediaType: mediaType,
      pagesCount: mediaPagesCount,
      comment: mediaComment,
      mediaProfile: mediaProfile.flatMap(MediaProfile.init),
      epubDivinaCompatible: mediaEpubDivinaCompatible,
      epubIsKepub: mediaEpubIsKepub
    )
  }

  var metadata: BookMetadata {
    BookMetadata(
      created: metaCreated,
      lastModified: metaLastModified,
      title: metaTitle,
      titleLock: metaTitleLock,
      summary: metaSummary,
      summaryLock: metaSummaryLock,
      number: metaNumber,
      numberLock: metaNumberLock,
      numberSort: metaNumberSort,
      numberSortLock: metaNumberSortLock,
      releaseDate: metaReleaseDate,
      releaseDateLock: metaReleaseDateLock,
      authors: metaAuthorsRaw.flatMap { try? JSONDecoder().decode([Author].self, from: $0) },
      authorsLock: metaAuthorsLock,
      tags: metaTags,
      tagsLock: metaTagsLock,
      isbn: metaIsbn,
      isbnLock: metaIsbnLock,
      links: metaLinksRaw.flatMap { try? JSONDecoder().decode([WebLink].self, from: $0) },
      linksLock: metaLinksLock
    )
  }

  var readProgress: ReadProgress? {
    guard let page = progressPage,
      let completed = progressCompleted,
      let readDate = progressReadDate,
      let created = progressCreated,
      let lastModified = progressLastModified
    else { return nil }
    return ReadProgress(
      page: page,
      completed: completed,
      readDate: readDate,
      created: created,
      lastModified: lastModified
    )
  }

  func toBook() -> Book {
    Book(
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
