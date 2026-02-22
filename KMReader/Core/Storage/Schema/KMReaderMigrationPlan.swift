//
// KMReaderMigrationPlan.swift
//
//

import Foundation
import SwiftData

nonisolated private struct MigrationBookSnapshot: Codable {
  let id: String
  let media: Media
  let metadata: BookMetadata
  let readProgress: ReadProgress?
}

nonisolated private struct MigrationSeriesSnapshot: Codable {
  let id: String
  let metadata: SeriesMetadata
  let booksMetadata: SeriesBooksMetadata
}

nonisolated private enum MigrationSnapshotStore {
  private static let directoryName = "kmreader_swiftdata_v1_v2_migration"
  private static let booksPrefix = "books"
  private static let seriesPrefix = "series"

  private static var directoryURL: URL {
    let baseURL =
      FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
      ?? FileManager.default.temporaryDirectory
    return baseURL.appendingPathComponent(directoryName, isDirectory: true)
  }

  static func prepare() throws {
    clear()
    try FileManager.default.createDirectory(
      at: directoryURL,
      withIntermediateDirectories: true,
      attributes: nil
    )
  }

  static func writeBookChunk(_ chunk: [MigrationBookSnapshot], index: Int) throws {
    try writeChunk(chunk, prefix: booksPrefix, index: index)
  }

  static func writeSeriesChunk(_ chunk: [MigrationSeriesSnapshot], index: Int) throws {
    try writeChunk(chunk, prefix: seriesPrefix, index: index)
  }

  static func readBookChunk(at url: URL) throws -> [MigrationBookSnapshot] {
    try readChunk(at: url)
  }

  static func readSeriesChunk(at url: URL) throws -> [MigrationSeriesSnapshot] {
    try readChunk(at: url)
  }

  static func bookChunkURLs() -> [URL] {
    chunkURLs(prefix: booksPrefix)
  }

  static func seriesChunkURLs() -> [URL] {
    chunkURLs(prefix: seriesPrefix)
  }

  private static func writeChunk<T: Encodable>(
    _ chunk: [T],
    prefix: String,
    index: Int
  ) throws {
    guard !chunk.isEmpty else { return }
    let data = try JSONEncoder().encode(chunk)
    try data.write(to: chunkURL(prefix: prefix, index: index), options: .atomic)
  }

  private static func readChunk<T: Decodable>(at url: URL) throws -> [T] {
    let data = try Data(contentsOf: url)
    return try JSONDecoder().decode([T].self, from: data)
  }

  private static func chunkURL(prefix: String, index: Int) -> URL {
    let filename = "\(prefix)-\(String(format: "%05d", index)).json"
    return directoryURL.appendingPathComponent(filename)
  }

  private static func chunkURLs(prefix: String) -> [URL] {
    guard
      let urls = try? FileManager.default.contentsOfDirectory(
        at: directoryURL,
        includingPropertiesForKeys: nil
      )
    else {
      return []
    }
    return
      urls
      .filter { $0.lastPathComponent.hasPrefix("\(prefix)-") }
      .sorted { $0.lastPathComponent < $1.lastPathComponent }
  }

  static func clear() {
    try? FileManager.default.removeItem(at: directoryURL)
  }
}

enum KMReaderMigrationPlan: SchemaMigrationPlan {
  private static let migrationBatchSize = 500

  static var schemas: [any VersionedSchema.Type] {
    [
      KMReaderSchemaV1.self,
      KMReaderSchemaV2.self,
      KMReaderSchemaV3.self,
    ]
  }

  static var stages: [MigrationStage] {
    [
      migrateV1toV2,
      migrateV2toV3,
    ]
  }

  static let migrateV1toV2 = MigrationStage.custom(
    fromVersion: KMReaderSchemaV1.self,
    toVersion: KMReaderSchemaV2.self,
    willMigrate: { context in
      try MigrationSnapshotStore.prepare()
      try snapshotBooks(context: context)
      try snapshotSeries(context: context)
    },
    didMigrate: { context in
      defer { MigrationSnapshotStore.clear() }

      try applyBookSnapshots(context: context)
      try applySeriesSnapshots(context: context)

      if context.hasChanges {
        try context.save()
      }
    }
  )

  static let migrateV2toV3 = MigrationStage.lightweight(
    fromVersion: KMReaderSchemaV2.self,
    toVersion: KMReaderSchemaV3.self
  )

  private static func snapshotBooks(context: ModelContext) throws {
    var offset = 0
    var chunkIndex = 0

    while true {
      var descriptor = FetchDescriptor<KMReaderSchemaV1.KomgaBook>(
        sortBy: [SortDescriptor(\KMReaderSchemaV1.KomgaBook.id, order: .forward)]
      )
      descriptor.fetchOffset = offset
      descriptor.fetchLimit = migrationBatchSize

      let books = try context.fetch(descriptor)
      guard !books.isEmpty else { break }

      let chunk = books.map(makeBookSnapshot)
      try MigrationSnapshotStore.writeBookChunk(chunk, index: chunkIndex)

      offset += books.count
      chunkIndex += 1
    }
  }

  private static func snapshotSeries(context: ModelContext) throws {
    var offset = 0
    var chunkIndex = 0

    while true {
      var descriptor = FetchDescriptor<KMReaderSchemaV1.KomgaSeries>(
        sortBy: [SortDescriptor(\KMReaderSchemaV1.KomgaSeries.id, order: .forward)]
      )
      descriptor.fetchOffset = offset
      descriptor.fetchLimit = migrationBatchSize

      let series = try context.fetch(descriptor)
      guard !series.isEmpty else { break }

      let chunk = series.map(makeSeriesSnapshot)
      try MigrationSnapshotStore.writeSeriesChunk(chunk, index: chunkIndex)

      offset += series.count
      chunkIndex += 1
    }
  }

  private static func applyBookSnapshots(context: ModelContext) throws {
    for chunkURL in MigrationSnapshotStore.bookChunkURLs() {
      let snapshots = try MigrationSnapshotStore.readBookChunk(at: chunkURL)
      guard !snapshots.isEmpty else { continue }

      let byID = Dictionary(uniqueKeysWithValues: snapshots.map { ($0.id, $0) })
      let ids = Set(byID.keys)
      let descriptor = FetchDescriptor<KomgaBook>(
        predicate: #Predicate { ids.contains($0.id) }
      )
      let books = try context.fetch(descriptor)

      for book in books {
        guard let snapshot = byID[book.id] else { continue }
        book.applyContent(
          media: snapshot.media,
          metadata: snapshot.metadata,
          readProgress: snapshot.readProgress
        )
      }

      if context.hasChanges {
        try context.save()
      }
    }
  }

  private static func applySeriesSnapshots(context: ModelContext) throws {
    for chunkURL in MigrationSnapshotStore.seriesChunkURLs() {
      let snapshots = try MigrationSnapshotStore.readSeriesChunk(at: chunkURL)
      guard !snapshots.isEmpty else { continue }

      let byID = Dictionary(uniqueKeysWithValues: snapshots.map { ($0.id, $0) })
      let ids = Set(byID.keys)
      let descriptor = FetchDescriptor<KomgaSeries>(
        predicate: #Predicate { ids.contains($0.id) }
      )
      let seriesList = try context.fetch(descriptor)

      for series in seriesList {
        guard let snapshot = byID[series.id] else { continue }
        series.applyContent(
          metadata: snapshot.metadata,
          booksMetadata: snapshot.booksMetadata
        )
      }

      if context.hasChanges {
        try context.save()
      }
    }
  }

  private static func makeBookSnapshot(_ book: KMReaderSchemaV1.KomgaBook) -> MigrationBookSnapshot {
    let media = Media(
      status: book.mediaStatus.isEmpty ? MediaStatus.unknown.rawValue : book.mediaStatus,
      mediaType: book.mediaType,
      pagesCount: book.mediaPagesCount,
      comment: book.mediaComment,
      mediaProfile: book.mediaProfile,
      epubDivinaCompatible: book.mediaEpubDivinaCompatible,
      epubIsKepub: book.mediaEpubIsKepub
    )

    let metadata = BookMetadata(
      created: book.metaCreated,
      lastModified: book.metaLastModified,
      title: book.metaTitle,
      titleLock: book.metaTitleLock,
      summary: book.metaSummary,
      summaryLock: book.metaSummaryLock,
      number: book.metaNumber,
      numberLock: book.metaNumberLock,
      numberSort: book.metaNumberSort,
      numberSortLock: book.metaNumberSortLock,
      releaseDate: book.metaReleaseDate,
      releaseDateLock: book.metaReleaseDateLock,
      authors: decode([Author].self, from: book.metaAuthorsRaw),
      authorsLock: book.metaAuthorsLock,
      tags: decode([String].self, from: book.metaTagsRaw),
      tagsLock: book.metaTagsLock,
      isbn: book.metaIsbn,
      isbnLock: book.metaIsbnLock,
      links: decode([WebLink].self, from: book.metaLinksRaw),
      linksLock: book.metaLinksLock
    )

    let readProgress: ReadProgress?
    if let page = book.progressPage,
      let completed = book.progressCompleted,
      let readDate = book.progressReadDate,
      let lastModified = book.progressLastModified
    {
      let created = book.progressCreated ?? readDate
      readProgress = ReadProgress(
        page: page,
        completed: completed,
        readDate: readDate,
        created: created,
        lastModified: lastModified
      )
    } else {
      readProgress = nil
    }

    return MigrationBookSnapshot(
      id: book.id,
      media: media,
      metadata: metadata,
      readProgress: readProgress
    )
  }

  private static func makeSeriesSnapshot(_ series: KMReaderSchemaV1.KomgaSeries) -> MigrationSeriesSnapshot {
    let metadata = SeriesMetadata(
      status: series.metaStatus,
      statusLock: series.metaStatusLock,
      created: series.metaCreated,
      lastModified: series.metaLastModified,
      title: series.metaTitle,
      titleLock: series.metaTitleLock,
      titleSort: series.metaTitleSort,
      titleSortLock: series.metaTitleSortLock,
      summary: series.metaSummary,
      summaryLock: series.metaSummaryLock,
      readingDirection: series.metaReadingDirection,
      readingDirectionLock: series.metaReadingDirectionLock,
      publisher: series.metaPublisher,
      publisherLock: series.metaPublisherLock,
      ageRating: series.metaAgeRating,
      ageRatingLock: series.metaAgeRatingLock,
      language: series.metaLanguage,
      languageLock: series.metaLanguageLock,
      genres: decode([String].self, from: series.metaGenresRaw),
      genresLock: series.metaGenresLock,
      tags: decode([String].self, from: series.metaTagsRaw),
      tagsLock: series.metaTagsLock,
      totalBookCount: series.metaTotalBookCount,
      totalBookCountLock: series.metaTotalBookCountLock,
      sharingLabels: decode([String].self, from: series.metaSharingLabelsRaw),
      sharingLabelsLock: series.metaSharingLabelsLock,
      links: decode([WebLink].self, from: series.metaLinksRaw),
      linksLock: series.metaLinksLock,
      alternateTitles: decode([AlternateTitle].self, from: series.metaAlternateTitlesRaw),
      alternateTitlesLock: series.metaAlternateTitlesLock
    )

    let booksMetadata = SeriesBooksMetadata(
      created: series.booksMetaCreated,
      lastModified: series.booksMetaLastModified,
      authors: decode([Author].self, from: series.booksMetaAuthorsRaw),
      tags: decode([String].self, from: series.booksMetaTagsRaw),
      releaseDate: series.booksMetaReleaseDate,
      summary: series.booksMetaSummary,
      summaryNumber: series.booksMetaSummaryNumber
    )

    return MigrationSeriesSnapshot(
      id: series.id,
      metadata: metadata,
      booksMetadata: booksMetadata
    )
  }

  private static func decode<T: Decodable>(_ type: T.Type, from data: Data?) -> T? {
    guard let data else {
      return nil
    }
    return try? JSONDecoder().decode(type, from: data)
  }
}
