//
// KomgaBookRecord.swift
//
//

import Foundation
import SQLiteData

@Table("komga_books")
nonisolated struct KomgaBookRecord: Hashable, Sendable {
  // API identifiers.
  var bookId: String
  var seriesId: String
  var libraryId: String
  var instanceId: String

  // API scalar fields.
  var name: String
  var url: String
  var seriesTitle: String = ""
  var number: Double
  @Column(as: Date.UnixTimeRepresentation.self)
  var created: Date
  @Column(as: Date.UnixTimeRepresentation.self)
  var lastModified: Date
  var sizeBytes: Int64
  var size: String
  var deleted: Bool = false
  var oneshot: Bool

  // API-aligned payloads
  var mediaRaw: Data?
  var metadataRaw: Data?
  var readProgressRaw: Data?

  // Query-only projections for filtering/sorting. UI must read from decoded API payloads.
  var mediaProfile: String?
  var mediaPagesCount: Int
  var metaTitle: String
  var metaNumber: String
  var metaNumberSort: Double
  var metaReleaseDate: String?
  var progressPage: Int?
  var progressCompleted: Bool?
  @Column(as: Date?.UnixTimeRepresentation.self)
  var progressReadDate: Date?
  @Column(as: Date?.UnixTimeRepresentation.self)
  var progressCreated: Date?
  @Column(as: Date?.UnixTimeRepresentation.self)
  var progressLastModified: Date?

  init(
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
    deleted: Bool,
    oneshot: Bool,
    seriesTitle: String = ""
  ) {
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
    self.mediaRaw = nil
    self.metadataRaw = nil
    self.readProgressRaw = nil
    self.mediaProfile = nil
    self.mediaPagesCount = 0
    self.metaTitle = ""
    self.metaNumber = ""
    self.metaNumberSort = 0
    self.metaReleaseDate = nil
    self.progressPage = nil
    self.progressCompleted = nil
    self.progressReadDate = nil
    self.progressCreated = nil
    self.progressLastModified = nil
    self.deleted = deleted
    self.oneshot = oneshot
    self.seriesTitle = seriesTitle

    setMedia(media)
    setMetadata(metadata)
    setReadProgress(readProgress)
  }

  mutating func setMedia(_ media: Media) {
    mediaRaw = try? JSONEncoder().encode(media)
    mediaProfile = media.mediaProfileRaw
    mediaPagesCount = media.pagesCount
  }

  mutating func setMetadata(_ metadata: BookMetadata) {
    metadataRaw = try? JSONEncoder().encode(metadata)
    metaTitle = metadata.title
    metaNumber = metadata.number
    metaNumberSort = metadata.numberSort
    metaReleaseDate = metadata.releaseDate
  }

  mutating func setReadProgress(_ readProgress: ReadProgress?) {
    readProgressRaw = readProgress.flatMap { try? JSONEncoder().encode($0) }
    progressPage = readProgress?.page
    progressCompleted = readProgress?.completed
    progressReadDate = readProgress?.readDate
    progressCreated = readProgress?.created
    progressLastModified = readProgress?.lastModified
  }

  var media: Media {
    if let mediaRaw, let decoded = try? JSONDecoder().decode(Media.self, from: mediaRaw) {
      return decoded
    }
    return Media(
      status: .unknown,
      mediaType: "",
      pagesCount: mediaPagesCount,
      comment: nil,
      mediaProfile: mediaProfile.flatMap(MediaProfile.init),
      epubDivinaCompatible: nil,
      epubIsKepub: nil
    )
  }

  var metadata: BookMetadata {
    if let metadataRaw, let decoded = try? JSONDecoder().decode(BookMetadata.self, from: metadataRaw) {
      return decoded
    }
    return BookMetadata(
      created: nil,
      lastModified: nil,
      title: metaTitle,
      titleLock: nil,
      summary: nil,
      summaryLock: nil,
      number: metaNumber,
      numberLock: nil,
      numberSort: metaNumberSort,
      numberSortLock: nil,
      releaseDate: metaReleaseDate,
      releaseDateLock: nil,
      authors: nil,
      authorsLock: nil,
      tags: nil,
      tagsLock: nil,
      isbn: nil,
      isbnLock: nil,
      links: nil,
      linksLock: nil
    )
  }

  var readProgress: ReadProgress? {
    if let readProgressRaw, let decoded = try? JSONDecoder().decode(ReadProgress.self, from: readProgressRaw) {
      return decoded
    }
    guard let page = progressPage,
      let completed = progressCompleted,
      let readDate = progressReadDate,
      let lastModified = progressLastModified
    else { return nil }
    let created = progressCreated ?? readDate
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
      deleted: deleted,
      oneshot: oneshot
    )
  }
}
