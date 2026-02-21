//
// AppSQLiteBootstrap.swift
//
//

import Dependencies
import Foundation
import SQLiteData
import SwiftData

@MainActor
enum AppSQLiteBootstrap {
  private static let logger = AppLogger(.database)

  static func bootstrap() {
    do {
      let database = try makeDatabase()
      try createSchema(database: database)

      let _ = prepareDependencies {
        $0.defaultDatabase = database
      }

      if needsLegacySwiftDataImport {
        let modelContainer = try makeLegacyModelContainer()
        try importFromSwiftDataIfNeeded(database: database, modelContainer: modelContainer)
      }
    } catch {
      logger.error("Failed to bootstrap app SQLite database: \(error.localizedDescription)")
    }
  }

  private static var needsLegacySwiftDataImport: Bool {
    !AppConfig.sqliteImportedFromSwiftDataV1
  }

  private static func makeLegacyModelContainer() throws -> ModelContainer {
    let schema = Schema([
      KomgaInstance.self,
      KomgaLibrary.self,
      KomgaSeries.self,
      KomgaBook.self,
      KomgaCollection.self,
      KomgaReadList.self,
      CustomFont.self,
      PendingProgress.self,
      SavedFilter.self,
      EpubThemePreset.self,
    ])
    let configuration = ModelConfiguration(schema: schema)
    return try ModelContainer(for: schema, configurations: [configuration])
  }

  private static func makeDatabase() throws -> DatabaseQueue {
    let appSupport =
      FileManager.default.urls(
        for: .applicationSupportDirectory, in: .userDomainMask
      ).first ?? FileManager.default.temporaryDirectory
    let sqliteDir = appSupport.appendingPathComponent("SQLiteData", isDirectory: true)
    try FileManager.default.createDirectory(at: sqliteDir, withIntermediateDirectories: true)
    let dbPath = sqliteDir.appendingPathComponent("app.sqlite")
    return try DatabaseQueue(path: dbPath.path)
  }

  private static func createSchema(database: DatabaseQueue) throws {
    try database.write { db in
      try #sql(
        """
        CREATE TABLE IF NOT EXISTS komga_instances (
          id TEXT PRIMARY KEY NOT NULL,
          name TEXT NOT NULL,
          serverURL TEXT NOT NULL,
          username TEXT NOT NULL,
          authToken TEXT NOT NULL,
          isAdmin INTEGER NOT NULL,
          authMethodRaw TEXT,
          createdAt INTEGER NOT NULL,
          lastUsedAt INTEGER NOT NULL,
          seriesLastSyncedAt INTEGER NOT NULL,
          booksLastSyncedAt INTEGER NOT NULL
        ) STRICT
        """
      )
      .execute(db)
      try #sql("CREATE INDEX IF NOT EXISTS idx_komga_instances_lastUsedAt ON komga_instances(lastUsedAt DESC)")
        .execute(db)

      try #sql(
        """
        CREATE TABLE IF NOT EXISTS komga_libraries (
          id TEXT PRIMARY KEY NOT NULL,
          instanceId TEXT NOT NULL,
          libraryId TEXT NOT NULL,
          name TEXT NOT NULL,
          createdAt INTEGER NOT NULL,
          fileSize REAL,
          booksCount REAL,
          seriesCount REAL,
          sidecarsCount REAL,
          collectionsCount REAL,
          readlistsCount REAL
        ) STRICT
        """
      )
      .execute(db)
      try #sql(
        "CREATE UNIQUE INDEX IF NOT EXISTS idx_komga_libraries_instance_library ON komga_libraries(instanceId, libraryId)"
      )
      .execute(db)
      try #sql("CREATE INDEX IF NOT EXISTS idx_komga_libraries_name ON komga_libraries(name)").execute(db)

      try #sql(
        """
        CREATE TABLE IF NOT EXISTS komga_series (
          seriesId TEXT NOT NULL,
          libraryId TEXT NOT NULL,
          instanceId TEXT NOT NULL,
          name TEXT NOT NULL,
          url TEXT NOT NULL,
          created INTEGER NOT NULL,
          lastModified INTEGER NOT NULL,
          booksCount INTEGER NOT NULL,
          booksReadCount INTEGER NOT NULL,
          booksUnreadCount INTEGER NOT NULL,
          booksInProgressCount INTEGER NOT NULL,
          deleted INTEGER NOT NULL,
          oneshot INTEGER NOT NULL,
          metadataRaw BLOB,
          booksMetadataRaw BLOB,
          -- Query projection columns for filtering/sorting only.
          metaStatus TEXT,
          metaTitle TEXT NOT NULL,
          metaTitleSort TEXT NOT NULL,
          booksMetaReleaseDate TEXT
        ) STRICT
        """
      )
      .execute(db)
      try #sql("CREATE INDEX IF NOT EXISTS idx_komga_series_instance ON komga_series(instanceId)").execute(db)
      try #sql("CREATE INDEX IF NOT EXISTS idx_komga_series_library ON komga_series(libraryId)").execute(db)
      try #sql("CREATE INDEX IF NOT EXISTS idx_komga_series_seriesId ON komga_series(seriesId)").execute(db)
      try #sql(
        "CREATE UNIQUE INDEX IF NOT EXISTS idx_komga_series_instance_seriesId ON komga_series(instanceId, seriesId)"
      )
      .execute(db)
      try #sql("CREATE INDEX IF NOT EXISTS idx_komga_series_name ON komga_series(name)").execute(db)
      try #sql("CREATE INDEX IF NOT EXISTS idx_komga_series_lastModified ON komga_series(lastModified DESC)").execute(
        db)

      try #sql(
        """
        CREATE TABLE IF NOT EXISTS komga_series_local_state (
          instanceId TEXT NOT NULL,
          seriesId TEXT NOT NULL,
          downloadStatusRaw TEXT NOT NULL,
          downloadError TEXT,
          downloadAt INTEGER,
          downloadedSize INTEGER NOT NULL,
          downloadedBooks INTEGER NOT NULL,
          pendingBooks INTEGER NOT NULL,
          offlinePolicyRaw TEXT NOT NULL,
          offlinePolicyLimit INTEGER NOT NULL,
          collectionIdsRaw BLOB
        ) STRICT
        """
      )
      .execute(db)
      try #sql(
        "CREATE UNIQUE INDEX IF NOT EXISTS idx_komga_series_local_state_instance_series ON komga_series_local_state(instanceId, seriesId)"
      )
      .execute(db)
      try #sql(
        "CREATE INDEX IF NOT EXISTS idx_komga_series_local_state_download_status ON komga_series_local_state(downloadStatusRaw)"
      )
      .execute(db)
      try #sql(
        "CREATE INDEX IF NOT EXISTS idx_komga_series_local_state_download_at ON komga_series_local_state(downloadAt)"
      )
      .execute(db)

      try #sql(
        """
        CREATE TABLE IF NOT EXISTS komga_books (
          bookId TEXT NOT NULL,
          seriesId TEXT NOT NULL,
          libraryId TEXT NOT NULL,
          instanceId TEXT NOT NULL,
          name TEXT NOT NULL,
          url TEXT NOT NULL,
          number REAL NOT NULL,
          created INTEGER NOT NULL,
          lastModified INTEGER NOT NULL,
          sizeBytes INTEGER NOT NULL,
          size TEXT NOT NULL,
          seriesTitle TEXT NOT NULL,
          deleted INTEGER NOT NULL,
          oneshot INTEGER NOT NULL,
          mediaRaw BLOB,
          metadataRaw BLOB,
          readProgressRaw BLOB,
          -- Query projection columns for filtering/sorting only.
          mediaProfile TEXT,
          mediaPagesCount INTEGER NOT NULL,
          metaTitle TEXT NOT NULL,
          metaNumber TEXT NOT NULL,
          metaNumberSort REAL NOT NULL,
          metaReleaseDate TEXT,
          progressPage INTEGER,
          progressCompleted INTEGER,
          progressReadDate INTEGER,
          progressCreated INTEGER,
          progressLastModified INTEGER
        ) STRICT
        """
      )
      .execute(db)
      try #sql("CREATE INDEX IF NOT EXISTS idx_komga_books_instance ON komga_books(instanceId)").execute(db)
      try #sql("CREATE INDEX IF NOT EXISTS idx_komga_books_series ON komga_books(seriesId)").execute(db)
      try #sql("CREATE INDEX IF NOT EXISTS idx_komga_books_library ON komga_books(libraryId)").execute(db)
      try #sql("CREATE INDEX IF NOT EXISTS idx_komga_books_bookId ON komga_books(bookId)").execute(db)
      try #sql("CREATE UNIQUE INDEX IF NOT EXISTS idx_komga_books_instance_bookId ON komga_books(instanceId, bookId)")
        .execute(db)
      try #sql("CREATE INDEX IF NOT EXISTS idx_komga_books_name ON komga_books(name)").execute(db)
      try #sql("CREATE INDEX IF NOT EXISTS idx_komga_books_lastModified ON komga_books(lastModified DESC)").execute(db)

      try #sql(
        """
        CREATE TABLE IF NOT EXISTS komga_book_local_state (
          instanceId TEXT NOT NULL,
          bookId TEXT NOT NULL,
          pagesRaw BLOB,
          tocRaw BLOB,
          webPubManifestRaw BLOB,
          epubProgressionRaw BLOB,
          isolatePagesRaw BLOB,
          epubPreferencesRaw TEXT,
          downloadStatusRaw TEXT NOT NULL,
          downloadError TEXT,
          downloadAt INTEGER,
          downloadedSize INTEGER NOT NULL,
          readListIdsRaw BLOB
        ) STRICT
        """
      )
      .execute(db)
      try #sql(
        "CREATE UNIQUE INDEX IF NOT EXISTS idx_komga_book_local_state_instance_book ON komga_book_local_state(instanceId, bookId)"
      )
      .execute(db)
      try #sql(
        "CREATE INDEX IF NOT EXISTS idx_komga_book_local_state_download_status ON komga_book_local_state(downloadStatusRaw)"
      )
      .execute(db)
      try #sql(
        "CREATE INDEX IF NOT EXISTS idx_komga_book_local_state_download_at ON komga_book_local_state(downloadAt)"
      )
      .execute(db)

      try #sql(
        """
        CREATE TABLE IF NOT EXISTS komga_collections (
          collectionId TEXT NOT NULL,
          instanceId TEXT NOT NULL,
          name TEXT NOT NULL,
          ordered INTEGER NOT NULL,
          createdDate INTEGER NOT NULL,
          lastModifiedDate INTEGER NOT NULL,
          filtered INTEGER NOT NULL,
          seriesIdsRaw BLOB
        ) STRICT
        """
      )
      .execute(db)
      try #sql("CREATE INDEX IF NOT EXISTS idx_komga_collections_instance ON komga_collections(instanceId)").execute(db)
      try #sql("CREATE INDEX IF NOT EXISTS idx_komga_collections_collectionId ON komga_collections(collectionId)")
        .execute(db)
      try #sql(
        "CREATE UNIQUE INDEX IF NOT EXISTS idx_komga_collections_instance_collectionId ON komga_collections(instanceId, collectionId)"
      )
      .execute(db)

      try #sql(
        """
        CREATE TABLE IF NOT EXISTS komga_read_lists (
          readListId TEXT NOT NULL,
          instanceId TEXT NOT NULL,
          name TEXT NOT NULL,
          summary TEXT NOT NULL,
          ordered INTEGER NOT NULL,
          createdDate INTEGER NOT NULL,
          lastModifiedDate INTEGER NOT NULL,
          filtered INTEGER NOT NULL,
          bookIdsRaw BLOB
        ) STRICT
        """
      )
      .execute(db)
      try #sql("CREATE INDEX IF NOT EXISTS idx_komga_read_lists_instance ON komga_read_lists(instanceId)").execute(db)
      try #sql("CREATE INDEX IF NOT EXISTS idx_komga_read_lists_readListId ON komga_read_lists(readListId)").execute(db)
      try #sql(
        "CREATE UNIQUE INDEX IF NOT EXISTS idx_komga_read_lists_instance_readListId ON komga_read_lists(instanceId, readListId)"
      )
      .execute(db)

      try #sql(
        """
        CREATE TABLE IF NOT EXISTS komga_read_list_local_state (
          instanceId TEXT NOT NULL,
          readListId TEXT NOT NULL,
          downloadStatusRaw TEXT NOT NULL,
          downloadError TEXT,
          downloadAt INTEGER,
          downloadedSize INTEGER NOT NULL,
          downloadedBooks INTEGER NOT NULL,
          pendingBooks INTEGER NOT NULL
        ) STRICT
        """
      )
      .execute(db)
      try #sql(
        "CREATE UNIQUE INDEX IF NOT EXISTS idx_komga_read_list_local_state_instance_readList ON komga_read_list_local_state(instanceId, readListId)"
      )
      .execute(db)
      try #sql(
        "CREATE INDEX IF NOT EXISTS idx_komga_read_list_local_state_download_status ON komga_read_list_local_state(downloadStatusRaw)"
      )
      .execute(db)
      try #sql(
        "CREATE INDEX IF NOT EXISTS idx_komga_read_list_local_state_download_at ON komga_read_list_local_state(downloadAt)"
      )
      .execute(db)

      try #sql(
        """
        CREATE TABLE IF NOT EXISTS pending_progress (
          id TEXT PRIMARY KEY NOT NULL,
          instanceId TEXT NOT NULL,
          bookId TEXT NOT NULL,
          page INTEGER NOT NULL,
          completed INTEGER NOT NULL,
          createdAt INTEGER NOT NULL,
          progressionData BLOB
        ) STRICT
        """
      )
      .execute(db)
      try #sql("CREATE INDEX IF NOT EXISTS idx_pending_progress_instance ON pending_progress(instanceId)").execute(db)
      try #sql("CREATE INDEX IF NOT EXISTS idx_pending_progress_createdAt ON pending_progress(createdAt ASC)").execute(
        db)

      try #sql(
        """
        CREATE TABLE IF NOT EXISTS custom_fonts (
          id TEXT PRIMARY KEY NOT NULL,
          name TEXT NOT NULL UNIQUE,
          path TEXT,
          fileName TEXT,
          fileSize INTEGER,
          createdAt INTEGER NOT NULL
        ) STRICT
        """
      )
      .execute(db)

      try #sql(
        """
        CREATE TABLE IF NOT EXISTS epub_theme_presets (
          id TEXT PRIMARY KEY NOT NULL,
          name TEXT NOT NULL,
          preferencesJSON TEXT NOT NULL,
          createdAt INTEGER NOT NULL,
          updatedAt INTEGER NOT NULL
        ) STRICT
        """
      )
      .execute(db)

      try #sql("CREATE INDEX IF NOT EXISTS idx_custom_fonts_name ON custom_fonts(name)").execute(db)
      try #sql(
        "CREATE INDEX IF NOT EXISTS idx_epub_theme_presets_updatedAt ON epub_theme_presets(updatedAt DESC)"
      )
      .execute(db)

      try #sql(
        """
        CREATE TABLE IF NOT EXISTS saved_filters (
          id TEXT PRIMARY KEY NOT NULL,
          name TEXT NOT NULL,
          filterTypeRaw TEXT NOT NULL,
          filterDataJSON TEXT NOT NULL,
          createdAt INTEGER NOT NULL,
          updatedAt INTEGER NOT NULL
        ) STRICT
        """
      )
      .execute(db)

      try #sql("CREATE INDEX IF NOT EXISTS idx_saved_filters_type ON saved_filters(filterTypeRaw)")
        .execute(db)
      try #sql("CREATE INDEX IF NOT EXISTS idx_saved_filters_updatedAt ON saved_filters(updatedAt DESC)")
        .execute(db)
    }
  }

  private static func importFromSwiftDataIfNeeded(
    database: DatabaseQueue,
    modelContainer: ModelContainer
  ) throws {
    guard !AppConfig.sqliteImportedFromSwiftDataV1 else { return }

    let context = ModelContext(modelContainer)
    let instances = try context.fetch(FetchDescriptor<KomgaInstance>())
    let libraries = try context.fetch(FetchDescriptor<KomgaLibrary>())
    let series = try context.fetch(FetchDescriptor<KomgaSeries>())
    let books = try context.fetch(FetchDescriptor<KomgaBook>())
    let collections = try context.fetch(FetchDescriptor<KomgaCollection>())
    let readLists = try context.fetch(FetchDescriptor<KomgaReadList>())
    let pendingProgress = try context.fetch(FetchDescriptor<PendingProgress>())
    let customFonts = try context.fetch(FetchDescriptor<CustomFont>())
    let presets = try context.fetch(FetchDescriptor<EpubThemePreset>())
    let savedFilters = try context.fetch(FetchDescriptor<SavedFilter>())

    try database.write { db in
      for instance in instances {
        try upsertInstance(instance, in: db)
      }
      for library in libraries {
        try upsertLibrary(library, in: db)
      }
      for item in series {
        try upsertSeries(item, in: db)
      }
      for item in books {
        try upsertBook(item, in: db)
      }
      for item in collections {
        try upsertCollection(item, in: db)
      }
      for item in readLists {
        try upsertReadList(item, in: db)
      }
      for item in pendingProgress {
        try upsertPendingProgress(item, in: db)
      }
      for font in customFonts {
        try upsertCustomFont(font, in: db)
      }
      for preset in presets {
        try EpubThemePresetRecord.upsert {
          EpubThemePresetRecord.Draft(
            id: preset.id,
            name: preset.name,
            preferencesJSON: preset.preferencesJSON,
            createdAt: preset.createdAt,
            updatedAt: preset.updatedAt
          )
        }
        .execute(db)
      }
      for filter in savedFilters {
        try SavedFilterRecord.upsert {
          SavedFilterRecord.Draft(
            id: filter.id,
            name: filter.name,
            filterTypeRaw: filter.filterTypeRaw,
            filterDataJSON: filter.filterDataJSON,
            createdAt: filter.createdAt,
            updatedAt: filter.updatedAt
          )
        }
        .execute(db)
      }
    }

    AppConfig.sqliteImportedFromSwiftDataV1 = true
    logger.info(
      "Imported legacy SwiftData data (instances=\(instances.count), libraries=\(libraries.count), series=\(series.count), books=\(books.count), collections=\(collections.count), readLists=\(readLists.count), pending=\(pendingProgress.count), fonts=\(customFonts.count), presets=\(presets.count), filters=\(savedFilters.count))"
    )
  }

  private static func upsertInstance(_ instance: KomgaInstance, in db: Database) throws {
    try KomgaInstanceRecord.upsert {
      KomgaInstanceRecord.Draft(
        id: instance.id,
        name: instance.name,
        serverURL: instance.serverURL,
        username: instance.username,
        authToken: instance.authToken,
        isAdmin: instance.isAdmin,
        authMethodRaw: instance.authMethod?.rawValue,
        createdAt: instance.createdAt,
        lastUsedAt: instance.lastUsedAt,
        seriesLastSyncedAt: instance.seriesLastSyncedAt,
        booksLastSyncedAt: instance.booksLastSyncedAt
      )
    }
    .execute(db)
  }

  private static func upsertLibrary(_ library: KomgaLibrary, in db: Database) throws {
    try KomgaLibraryRecord.upsert {
      KomgaLibraryRecord.Draft(
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
    }
    .execute(db)
  }

  private static func upsertSeries(_ series: KomgaSeries, in db: Database) throws {
    let record = KomgaSeriesRecord(
      seriesId: series.seriesId,
      libraryId: series.libraryId,
      instanceId: series.instanceId,
      name: series.name,
      url: series.url,
      created: series.created,
      lastModified: series.lastModified,
      booksCount: series.booksCount,
      booksReadCount: series.booksReadCount,
      booksUnreadCount: series.booksUnreadCount,
      booksInProgressCount: series.booksInProgressCount,
      metadata: series.metadata,
      booksMetadata: series.booksMetadata,
      deleted: series.isUnavailable,
      oneshot: series.oneshot
    )
    try insertOrUpdateSeriesRecord(record, in: db)

    let localState = KomgaSeriesLocalStateRecord(
      instanceId: series.instanceId,
      seriesId: series.seriesId,
      downloadStatusRaw: series.downloadStatusRaw,
      downloadError: series.downloadError,
      downloadAt: series.downloadAt,
      downloadedSize: series.downloadedSize,
      downloadedBooks: series.downloadedBooks,
      pendingBooks: series.pendingBooks,
      offlinePolicyRaw: series.offlinePolicyRaw,
      offlinePolicyLimit: series.offlinePolicyLimit,
      collectionIdsRaw: series.collectionIdsRaw
    )
    try insertOrUpdateSeriesLocalStateRecord(localState, in: db)
  }

  private static func upsertBook(_ book: KomgaBook, in db: Database) throws {
    let record = KomgaBookRecord(
      bookId: book.bookId,
      seriesId: book.seriesId,
      libraryId: book.libraryId,
      instanceId: book.instanceId,
      name: book.name,
      url: book.url,
      number: book.number,
      created: book.created,
      lastModified: book.lastModified,
      sizeBytes: book.sizeBytes,
      size: book.size,
      media: book.media,
      metadata: book.metadata,
      readProgress: book.readProgress,
      deleted: book.isUnavailable,
      oneshot: book.oneshot,
      seriesTitle: book.seriesTitle
    )
    try insertOrUpdateBookRecord(record, in: db)

    let localState = KomgaBookLocalStateRecord(
      instanceId: book.instanceId,
      bookId: book.bookId,
      pagesRaw: book.pagesRaw,
      tocRaw: book.tocRaw,
      webPubManifestRaw: book.webPubManifestRaw,
      epubProgressionRaw: book.epubProgressionRaw,
      isolatePagesRaw: book.isolatePagesRaw,
      epubPreferencesRaw: book.epubPreferencesRaw,
      downloadStatusRaw: book.downloadStatusRaw,
      downloadError: book.downloadError,
      downloadAt: book.downloadAt,
      downloadedSize: book.downloadedSize,
      readListIdsRaw: book.readListIdsRaw
    )
    try insertOrUpdateBookLocalStateRecord(localState, in: db)
  }

  private static func upsertCollection(_ collection: KomgaCollection, in db: Database) throws {
    try insertOrUpdateCollectionRecord(
      KomgaCollectionRecord(
        collectionId: collection.collectionId,
        instanceId: collection.instanceId,
        name: collection.name,
        ordered: collection.ordered,
        createdDate: collection.createdDate,
        lastModifiedDate: collection.lastModifiedDate,
        filtered: collection.filtered,
        seriesIds: collection.seriesIds
      ),
      in: db
    )
  }

  private static func upsertReadList(_ readList: KomgaReadList, in db: Database) throws {
    try insertOrUpdateReadListRecord(
      KomgaReadListRecord(
        readListId: readList.readListId,
        instanceId: readList.instanceId,
        name: readList.name,
        summary: readList.summary,
        ordered: readList.ordered,
        createdDate: readList.createdDate,
        lastModifiedDate: readList.lastModifiedDate,
        filtered: readList.filtered,
        bookIds: readList.bookIds
      ),
      in: db
    )

    try insertOrUpdateReadListLocalStateRecord(
      KomgaReadListLocalStateRecord(
        instanceId: readList.instanceId,
        readListId: readList.readListId,
        downloadStatusRaw: readList.downloadStatusRaw,
        downloadError: readList.downloadError,
        downloadAt: readList.downloadAt,
        downloadedSize: readList.downloadedSize,
        downloadedBooks: readList.downloadedBooks,
        pendingBooks: readList.pendingBooks
      ),
      in: db
    )
  }

  private static func insertOrUpdateBookRecord(_ record: KomgaBookRecord, in db: Database) throws {
    let query = KomgaBookRecord.where { $0.instanceId.eq(record.instanceId) && $0.bookId.eq(record.bookId) }

    if let existing = try query.fetchOne(db) {
      guard existing != record else { return }
      try query
        .update {
          $0.seriesId = #bind(record.seriesId)
          $0.libraryId = #bind(record.libraryId)
          $0.name = #bind(record.name)
          $0.url = #bind(record.url)
          $0.number = #bind(record.number)
          $0.created = #bind(record.created)
          $0.lastModified = #bind(record.lastModified)
          $0.sizeBytes = #bind(record.sizeBytes)
          $0.size = #bind(record.size)
          $0.seriesTitle = #bind(record.seriesTitle)
          $0.deleted = #bind(record.deleted)
          $0.oneshot = #bind(record.oneshot)
          $0.mediaRaw = #bind(record.mediaRaw)
          $0.metadataRaw = #bind(record.metadataRaw)
          $0.readProgressRaw = #bind(record.readProgressRaw)
          $0.mediaProfile = #bind(record.mediaProfile)
          $0.mediaPagesCount = #bind(record.mediaPagesCount)
          $0.metaTitle = #bind(record.metaTitle)
          $0.metaNumber = #bind(record.metaNumber)
          $0.metaNumberSort = #bind(record.metaNumberSort)
          $0.metaReleaseDate = #bind(record.metaReleaseDate)
          $0.progressPage = #bind(record.progressPage)
          $0.progressCompleted = #bind(record.progressCompleted)
          $0.progressReadDate = #bind(record.progressReadDate)
          $0.progressCreated = #bind(record.progressCreated)
          $0.progressLastModified = #bind(record.progressLastModified)
        }
        .execute(db)
      return
    }

    try KomgaBookRecord.insert { record }.execute(db)
  }

  private static func insertOrUpdateBookLocalStateRecord(_ record: KomgaBookLocalStateRecord, in db: Database) throws {
    let query = KomgaBookLocalStateRecord.where {
      $0.instanceId.eq(record.instanceId) && $0.bookId.eq(record.bookId)
    }

    if let existing = try query.fetchOne(db) {
      guard existing != record else { return }
      try query
        .update {
          $0.pagesRaw = #bind(record.pagesRaw)
          $0.tocRaw = #bind(record.tocRaw)
          $0.webPubManifestRaw = #bind(record.webPubManifestRaw)
          $0.epubProgressionRaw = #bind(record.epubProgressionRaw)
          $0.isolatePagesRaw = #bind(record.isolatePagesRaw)
          $0.epubPreferencesRaw = #bind(record.epubPreferencesRaw)
          $0.downloadStatusRaw = #bind(record.downloadStatusRaw)
          $0.downloadError = #bind(record.downloadError)
          $0.downloadAt = #bind(record.downloadAt)
          $0.downloadedSize = #bind(record.downloadedSize)
          $0.readListIdsRaw = #bind(record.readListIdsRaw)
        }
        .execute(db)
      return
    }

    try KomgaBookLocalStateRecord.insert { record }.execute(db)
  }

  private static func insertOrUpdateSeriesRecord(_ record: KomgaSeriesRecord, in db: Database) throws {
    let query = KomgaSeriesRecord.where { $0.instanceId.eq(record.instanceId) && $0.seriesId.eq(record.seriesId) }

    if let existing = try query.fetchOne(db) {
      guard existing != record else { return }
      try query
        .update {
          $0.libraryId = #bind(record.libraryId)
          $0.name = #bind(record.name)
          $0.url = #bind(record.url)
          $0.created = #bind(record.created)
          $0.lastModified = #bind(record.lastModified)
          $0.booksCount = #bind(record.booksCount)
          $0.booksReadCount = #bind(record.booksReadCount)
          $0.booksUnreadCount = #bind(record.booksUnreadCount)
          $0.booksInProgressCount = #bind(record.booksInProgressCount)
          $0.deleted = #bind(record.deleted)
          $0.oneshot = #bind(record.oneshot)
          $0.metadataRaw = #bind(record.metadataRaw)
          $0.booksMetadataRaw = #bind(record.booksMetadataRaw)
          $0.metaStatus = #bind(record.metaStatus)
          $0.metaTitle = #bind(record.metaTitle)
          $0.metaTitleSort = #bind(record.metaTitleSort)
          $0.booksMetaReleaseDate = #bind(record.booksMetaReleaseDate)
        }
        .execute(db)
      return
    }

    try KomgaSeriesRecord.insert { record }.execute(db)
  }

  private static func insertOrUpdateSeriesLocalStateRecord(
    _ record: KomgaSeriesLocalStateRecord,
    in db: Database
  ) throws {
    let query = KomgaSeriesLocalStateRecord.where {
      $0.instanceId.eq(record.instanceId) && $0.seriesId.eq(record.seriesId)
    }

    if let existing = try query.fetchOne(db) {
      guard existing != record else { return }
      try query
        .update {
          $0.downloadStatusRaw = #bind(record.downloadStatusRaw)
          $0.downloadError = #bind(record.downloadError)
          $0.downloadAt = #bind(record.downloadAt)
          $0.downloadedSize = #bind(record.downloadedSize)
          $0.downloadedBooks = #bind(record.downloadedBooks)
          $0.pendingBooks = #bind(record.pendingBooks)
          $0.offlinePolicyRaw = #bind(record.offlinePolicyRaw)
          $0.offlinePolicyLimit = #bind(record.offlinePolicyLimit)
          $0.collectionIdsRaw = #bind(record.collectionIdsRaw)
        }
        .execute(db)
      return
    }

    try KomgaSeriesLocalStateRecord.insert { record }.execute(db)
  }

  private static func insertOrUpdateCollectionRecord(_ record: KomgaCollectionRecord, in db: Database) throws {
    let query = KomgaCollectionRecord.where {
      $0.instanceId.eq(record.instanceId) && $0.collectionId.eq(record.collectionId)
    }

    if let existing = try query.fetchOne(db) {
      guard existing != record else { return }
      try query
        .update {
          $0.name = #bind(record.name)
          $0.ordered = #bind(record.ordered)
          $0.createdDate = #bind(record.createdDate)
          $0.lastModifiedDate = #bind(record.lastModifiedDate)
          $0.filtered = #bind(record.filtered)
          $0.seriesIdsRaw = #bind(record.seriesIdsRaw)
        }
        .execute(db)
      return
    }

    try KomgaCollectionRecord.insert { record }.execute(db)
  }

  private static func insertOrUpdateReadListRecord(_ record: KomgaReadListRecord, in db: Database) throws {
    let query = KomgaReadListRecord.where {
      $0.instanceId.eq(record.instanceId) && $0.readListId.eq(record.readListId)
    }

    if let existing = try query.fetchOne(db) {
      guard existing != record else { return }
      try query
        .update {
          $0.name = #bind(record.name)
          $0.summary = #bind(record.summary)
          $0.ordered = #bind(record.ordered)
          $0.createdDate = #bind(record.createdDate)
          $0.lastModifiedDate = #bind(record.lastModifiedDate)
          $0.filtered = #bind(record.filtered)
          $0.bookIdsRaw = #bind(record.bookIdsRaw)
        }
        .execute(db)
      return
    }

    try KomgaReadListRecord.insert { record }.execute(db)
  }

  private static func insertOrUpdateReadListLocalStateRecord(
    _ record: KomgaReadListLocalStateRecord,
    in db: Database
  ) throws {
    let query = KomgaReadListLocalStateRecord.where {
      $0.instanceId.eq(record.instanceId) && $0.readListId.eq(record.readListId)
    }

    if let existing = try query.fetchOne(db) {
      guard existing != record else { return }
      try query
        .update {
          $0.downloadStatusRaw = #bind(record.downloadStatusRaw)
          $0.downloadError = #bind(record.downloadError)
          $0.downloadAt = #bind(record.downloadAt)
          $0.downloadedSize = #bind(record.downloadedSize)
          $0.downloadedBooks = #bind(record.downloadedBooks)
          $0.pendingBooks = #bind(record.pendingBooks)
        }
        .execute(db)
      return
    }

    try KomgaReadListLocalStateRecord.insert { record }.execute(db)
  }

  private static func upsertPendingProgress(_ progress: PendingProgress, in db: Database) throws {
    try PendingProgressRecord.upsert {
      PendingProgressRecord.Draft(
        id: progress.id,
        instanceId: progress.instanceId,
        bookId: progress.bookId,
        page: progress.page,
        completed: progress.completed,
        createdAt: progress.createdAt,
        progressionData: progress.progressionData
      )
    }
    .execute(db)
  }

  private static func upsertCustomFont(_ font: CustomFont, in db: Database) throws {
    let existingID = try CustomFontRecord
      .where { $0.name.eq(font.name) }
      .fetchOne(db)?
      .id

    try CustomFontRecord.upsert {
      CustomFontRecord.Draft(
        id: existingID ?? UUID(),
        name: font.name,
        path: font.path,
        fileName: font.fileName,
        fileSize: font.fileSize,
        createdAt: font.createdAt
      )
    }
    .execute(db)
  }
}
