//
// LegacySwiftDataImporter.swift
//
//

import Foundation
import GRDB
import SwiftData

enum LegacySwiftDataImporter {
  static func importIfNeeded(into dbQueue: DatabaseQueue) throws {
    let marker = try dbQueue.read { db in
      try LocalMigrationMarker.fetchOne(db, key: LocalDatabase.legacyImportMarkerKey)
    }

    if marker?.state == .completed || marker?.state == .missing {
      return
    }

    guard legacyStoreExists() else {
      try writeMarker(.missing, message: nil, into: dbQueue)
      return
    }

    do {
      let container = try makeLegacyContainer()
      let context = ModelContext(container)
      try importAll(from: context, into: dbQueue)
      try writeMarker(.completed, message: nil, into: dbQueue)
    } catch {
      try? writeMarker(.failed, message: String(describing: error), into: dbQueue)
      throw error
    }
  }

  private static func legacyStoreExists(fileManager: FileManager = .default) -> Bool {
    LocalDatabase.legacyStoreCandidates(fileManager: fileManager).contains { url in
      fileManager.fileExists(atPath: url.path)
    }
  }

  private static func makeLegacyContainer() throws -> ModelContainer {
    let schema = Schema(versionedSchema: KMReaderSchemaV6.self)
    let configuration = ModelConfiguration(schema: schema)
    do {
      return try ModelContainer(
        for: schema,
        migrationPlan: KMReaderMigrationPlan.self,
        configurations: [configuration]
      )
    } catch {
      AppLogger(.database).warning(
        "Staged SwiftData legacy migration failed; retrying inferred migration for import only: \(String(describing: error))"
      )
      return try ModelContainer(for: schema, configurations: [configuration])
    }
  }

  private static func writeMarker(
    _ state: LegacyImportMarkerState,
    message: String?,
    into dbQueue: DatabaseQueue
  ) throws {
    try dbQueue.write { db in
      var marker = LocalMigrationMarker(
        key: LocalDatabase.legacyImportMarkerKey,
        state: state,
        message: message
      )
      try marker.save(db)
    }
  }

  private static func importAll(from context: ModelContext, into dbQueue: DatabaseQueue) throws {
    try importBatches(
      KMReaderSchemaV6.KomgaInstance.self,
      from: context,
      into: dbQueue,
      sortBy: [SortDescriptor(\.id, order: .forward)]
    ) { db, instance in
      var record = KomgaInstance(
        id: instance.id,
        name: instance.name,
        serverURL: instance.serverURL,
        username: instance.username,
        authToken: instance.authToken,
        isAdmin: instance.isAdmin,
        authMethod: instance.authMethod ?? .basicAuth,
        createdAt: instance.createdAt,
        lastUsedAt: instance.lastUsedAt,
        seriesLastSyncedAt: instance.seriesLastSyncedAt,
        booksLastSyncedAt: instance.booksLastSyncedAt
      )
      try record.save(db)
    }

    try importBatches(
      KMReaderSchemaV6.KomgaLibrary.self,
      from: context,
      into: dbQueue,
      sortBy: [SortDescriptor(\.id, order: .forward)]
    ) { db, library in
      var record = KomgaLibrary(
        id: library.id,
        instanceId: library.instanceId,
        libraryId: library.libraryId,
        name: library.name,
        createdAt: library.createdAt,
        fileSize: library.fileSize,
        booksCount: library.booksCount,
        seriesCount: library.seriesCount,
        sidecarsCount: library.sidecarsCount,
        collectionsCount: library.collectionsCount,
        readlistsCount: library.readlistsCount
      )
      try record.save(db)
    }

    try importBatches(
      KMReaderSchemaV6.KomgaSeries.self,
      from: context,
      into: dbQueue,
      sortBy: [SortDescriptor(\.id, order: .forward)]
    ) { db, item in
      let metadata = RawCodableStore.decode(SeriesMetadata.self, from: item.metadataRaw) ?? .empty
      let booksMetadata = RawCodableStore.decode(SeriesBooksMetadata.self, from: item.booksMetadataRaw) ?? .empty
      var record = KomgaSeries(
        id: item.id,
        seriesId: item.seriesId,
        libraryId: item.libraryId,
        instanceId: item.instanceId,
        name: item.name,
        url: item.url,
        created: item.created,
        lastModified: item.lastModified,
        booksCount: item.booksCount,
        booksReadCount: item.booksReadCount,
        booksUnreadCount: item.booksUnreadCount,
        booksInProgressCount: item.booksInProgressCount,
        metadata: metadata,
        booksMetadata: booksMetadata,
        isUnavailable: item.isUnavailable,
        oneshot: item.oneshot,
        downloadedBooks: item.downloadedBooks,
        pendingBooks: item.pendingBooks,
        downloadedSize: item.downloadedSize,
        offlinePolicy: SeriesOfflinePolicy(rawValue: item.offlinePolicyRaw) ?? .manual,
        offlinePolicyLimit: item.offlinePolicyLimit
      )
      record.metadataRaw = item.metadataRaw
      record.booksMetadataRaw = item.booksMetadataRaw
      record.metaTitle = item.metaTitle
      record.metaTitleSort = item.metaTitleSort
      record.metaPublisherIndex = item.metaPublisherIndex
      record.metaAuthorsIndex = item.metaAuthorsIndex
      record.metaGenresIndex = item.metaGenresIndex
      record.metaTagsIndex = item.metaTagsIndex
      record.metaLanguageIndex = item.metaLanguageIndex
      record.downloadStatusRaw = item.downloadStatusRaw
      record.downloadError = item.downloadError
      record.downloadAt = item.downloadAt
      record.collectionIdsRaw = item.collectionIdsRaw
      try record.save(db)
    }

    try importBatches(
      KMReaderSchemaV6.KomgaBook.self,
      from: context,
      into: dbQueue,
      sortBy: [SortDescriptor(\.id, order: .forward)]
    ) { db, item in
      let media = RawCodableStore.decode(Media.self, from: item.mediaRaw) ?? .empty
      let metadata = RawCodableStore.decode(BookMetadata.self, from: item.metadataRaw) ?? .empty
      let readProgress = RawCodableStore.decode(ReadProgress.self, from: item.readProgressRaw)
      var record = KomgaBook(
        id: item.id,
        bookId: item.bookId,
        seriesId: item.seriesId,
        libraryId: item.libraryId,
        instanceId: item.instanceId,
        name: item.name,
        url: item.url,
        number: item.number,
        created: item.created,
        lastModified: item.lastModified,
        sizeBytes: item.sizeBytes,
        size: item.size,
        media: media,
        metadata: metadata,
        readProgress: readProgress,
        isUnavailable: item.isUnavailable,
        oneshot: item.oneshot,
        seriesTitle: item.seriesTitle,
        downloadedSize: item.downloadedSize
      )
      record.mediaRaw = item.mediaRaw
      record.metadataRaw = item.metadataRaw
      record.readProgressRaw = item.readProgressRaw
      record.mediaPagesCount = item.mediaPagesCount
      record.mediaProfile = item.mediaProfile
      record.metaTitle = item.metaTitle
      record.metaNumber = item.metaNumber
      record.metaNumberSort = item.metaNumberSort
      record.metaReleaseDate = item.metaReleaseDate
      record.progressPage = item.progressPage
      record.progressCompleted = item.progressCompleted
      record.progressReadDate = item.progressReadDate
      record.metaAuthorsIndex = item.metaAuthorsIndex
      record.metaTagsIndex = item.metaTagsIndex
      record.pagesRaw = item.pagesRaw
      record.tocRaw = item.tocRaw
      record.webPubManifestRaw = item.webPubManifestRaw
      record.epubProgressionRaw = item.epubProgressionRaw
      record.downloadStatusRaw = item.downloadStatusRaw
      record.downloadError = item.downloadError
      record.downloadAt = item.downloadAt
      record.readListIdsRaw = item.readListIdsRaw
      record.isolatePagesRaw = item.isolatePagesRaw
      record.pageRotationsRaw = item.pageRotationsRaw
      record.epubPreferencesRaw = item.epubPreferencesRaw
      try record.save(db)
    }

    try importBatches(
      KMReaderSchemaV6.KomgaCollection.self,
      from: context,
      into: dbQueue,
      sortBy: [SortDescriptor(\.id, order: .forward)]
    ) { db, item in
      let seriesIds = item.seriesIdsRaw.flatMap { try? JSONDecoder().decode([String].self, from: $0) } ?? []
      var record = KomgaCollection(
        id: item.id,
        collectionId: item.collectionId,
        instanceId: item.instanceId,
        name: item.name,
        ordered: item.ordered,
        createdDate: item.createdDate,
        lastModifiedDate: item.lastModifiedDate,
        filtered: item.filtered,
        isPinned: item.isPinned,
        seriesIds: seriesIds
      )
      record.seriesIdsRaw = item.seriesIdsRaw
      try record.save(db)
    }

    try importBatches(
      KMReaderSchemaV6.KomgaReadList.self,
      from: context,
      into: dbQueue,
      sortBy: [SortDescriptor(\.id, order: .forward)]
    ) { db, item in
      let bookIds = item.bookIdsRaw.flatMap { try? JSONDecoder().decode([String].self, from: $0) } ?? []
      var record = KomgaReadList(
        id: item.id,
        readListId: item.readListId,
        instanceId: item.instanceId,
        name: item.name,
        summary: item.summary,
        ordered: item.ordered,
        createdDate: item.createdDate,
        lastModifiedDate: item.lastModifiedDate,
        filtered: item.filtered,
        isPinned: item.isPinned,
        bookIds: bookIds,
        downloadedBooks: item.downloadedBooks,
        pendingBooks: item.pendingBooks,
        downloadedSize: item.downloadedSize
      )
      record.bookIdsRaw = item.bookIdsRaw
      record.downloadStatusRaw = item.downloadStatusRaw
      record.downloadError = item.downloadError
      record.downloadAt = item.downloadAt
      try record.save(db)
    }

    try importBatches(
      KMReaderSchemaV6.CustomFontV1.self,
      from: context,
      into: dbQueue,
      sortBy: [SortDescriptor(\.name, order: .forward)]
    ) { db, item in
      var record = CustomFont(
        name: item.name,
        path: item.path,
        fileName: item.fileName,
        fileSize: item.fileSize,
        createdAt: item.createdAt
      )
      try record.save(db)
    }

    try importBatches(
      KMReaderSchemaV6.PendingProgress.self,
      from: context,
      into: dbQueue,
      sortBy: [SortDescriptor(\.id, order: .forward)]
    ) { db, item in
      var record = PendingProgress(
        instanceId: item.instanceId,
        bookId: item.bookId,
        page: item.page,
        completed: item.completed,
        progressionData: item.progressionData,
        createdAt: item.createdAt
      )
      record.id = item.id
      try record.save(db)
    }

    try importBatches(
      KMReaderSchemaV6.SavedFilterV1.self,
      from: context,
      into: dbQueue,
      sortBy: [SortDescriptor(\.id, order: .forward)]
    ) { db, item in
      let filterType = SavedFilterType(rawValue: item.filterTypeRaw) ?? .series
      var record = SavedFilter(
        id: item.id,
        name: item.name,
        filterType: filterType,
        filterDataJSON: item.filterDataJSON,
        createdAt: item.createdAt,
        updatedAt: item.updatedAt
      )
      record.filterTypeRaw = item.filterTypeRaw
      try record.save(db)
    }

    try importBatches(
      KMReaderSchemaV6.EpubThemePresetV1.self,
      from: context,
      into: dbQueue,
      sortBy: [SortDescriptor(\.id, order: .forward)]
    ) { db, item in
      var record = EpubThemePreset(
        id: item.id,
        name: item.name,
        preferencesJSON: item.preferencesJSON,
        createdAt: item.createdAt,
        updatedAt: item.updatedAt
      )
      try record.save(db)
    }
  }

  private static func importBatches<LegacyModel: PersistentModel>(
    _ modelType: LegacyModel.Type,
    from context: ModelContext,
    into dbQueue: DatabaseQueue,
    sortBy: [SortDescriptor<LegacyModel>],
    importRecord: (Database, LegacyModel) throws -> Void
  ) throws {
    _ = modelType
    var offset = 0

    while true {
      var descriptor = FetchDescriptor<LegacyModel>(sortBy: sortBy)
      descriptor.fetchLimit = DatabaseOperator.recordFetchChunkSize
      descriptor.fetchOffset = offset

      let items = try context.fetch(descriptor)
      guard !items.isEmpty else { return }

      try dbQueue.write { db in
        for item in items {
          try importRecord(db, item)
        }
      }

      offset += items.count
    }
  }
}
