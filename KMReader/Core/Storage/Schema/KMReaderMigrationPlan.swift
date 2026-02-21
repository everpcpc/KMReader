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

nonisolated private struct MigrationSnapshot: Codable {
  let books: [MigrationBookSnapshot]
  let series: [MigrationSeriesSnapshot]
}

nonisolated private enum MigrationSnapshotStore {
  private static var snapshotURL: URL {
    FileManager.default.temporaryDirectory
      .appendingPathComponent("kmreader_swiftdata_v1_v2_migration")
      .appendingPathExtension("json")
  }

  static func write(_ snapshot: MigrationSnapshot) throws {
    clear()
    let data = try JSONEncoder().encode(snapshot)
    try data.write(to: snapshotURL, options: .atomic)
  }

  static func read() -> MigrationSnapshot? {
    guard let data = try? Data(contentsOf: snapshotURL) else {
      return nil
    }
    return try? JSONDecoder().decode(MigrationSnapshot.self, from: data)
  }

  static func clear() {
    try? FileManager.default.removeItem(at: snapshotURL)
  }
}

enum KMReaderMigrationPlan: SchemaMigrationPlan {
  static var schemas: [any VersionedSchema.Type] {
    [
      KMReaderSchemaV1.self,
      KMReaderSchemaV2.self,
    ]
  }

  static var stages: [MigrationStage] {
    [
      migrateV1toV2
    ]
  }

  static let migrateV1toV2 = MigrationStage.custom(
    fromVersion: KMReaderSchemaV1.self,
    toVersion: KMReaderSchemaV2.self,
    willMigrate: { context in
      let v1Books = try context.fetch(FetchDescriptor<KMReaderSchemaV1.KomgaBook>())
      let v1Series = try context.fetch(FetchDescriptor<KMReaderSchemaV1.KomgaSeries>())

      let snapshot = MigrationSnapshot(
        books: v1Books.map(makeBookSnapshot),
        series: v1Series.map(makeSeriesSnapshot)
      )

      try MigrationSnapshotStore.write(snapshot)
    },
    didMigrate: { context in
      defer { MigrationSnapshotStore.clear() }

      let snapshot = MigrationSnapshotStore.read()
      let bookSnapshots = Dictionary(uniqueKeysWithValues: snapshot?.books.map { ($0.id, $0) } ?? [])
      let seriesSnapshots = Dictionary(uniqueKeysWithValues: snapshot?.series.map { ($0.id, $0) } ?? [])

      let books = try context.fetch(FetchDescriptor<KomgaBook>())
      for book in books {
        if let item = bookSnapshots[book.id] {
          book.applyContent(media: item.media, metadata: item.metadata, readProgress: item.readProgress)
        } else {
          book.rebuildQueryFields()
        }
      }

      let seriesList = try context.fetch(FetchDescriptor<KomgaSeries>())
      for series in seriesList {
        if let item = seriesSnapshots[series.id] {
          series.applyContent(metadata: item.metadata, booksMetadata: item.booksMetadata)
        } else {
          series.rebuildQueryFields()
        }
      }

      if context.hasChanges {
        try context.save()
      }
    }
  )

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
