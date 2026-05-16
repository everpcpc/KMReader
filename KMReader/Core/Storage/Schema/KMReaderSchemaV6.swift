//
// KMReaderSchemaV6.swift
//
//

import Foundation
import SwiftData

enum KMReaderSchemaV6: VersionedSchema {
  static var versionIdentifier: Schema.Version {
    Schema.Version(6, 0, 0)
  }

  static var models: [any PersistentModel.Type] {
    [
      KMReaderSchemaV6.KomgaInstance.self,
      KMReaderSchemaV6.KomgaLibrary.self,
      KMReaderSchemaV6.KomgaSeries.self,
      KMReaderSchemaV6.KomgaBook.self,
      KMReaderSchemaV6.KomgaCollection.self,
      KMReaderSchemaV6.KomgaReadList.self,
      KMReaderSchemaV6.CustomFontV1.self,
      KMReaderSchemaV6.PendingProgress.self,
      KMReaderSchemaV6.SavedFilterV1.self,
      KMReaderSchemaV6.EpubThemePresetV1.self,
    ]
  }

  @Model
  final class KomgaInstance {
    @Attribute(.unique) var id: UUID
    var name: String
    var serverURL: String
    var username: String
    var authToken: String
    var isAdmin: Bool
    var authMethod: AuthenticationMethod? = AuthenticationMethod.basicAuth
    var createdAt: Date
    var lastUsedAt: Date
    var seriesLastSyncedAt: Date = Date(timeIntervalSince1970: 0)
    var booksLastSyncedAt: Date = Date(timeIntervalSince1970: 0)

    init(
      id: UUID = UUID(),
      name: String,
      serverURL: String,
      username: String,
      authToken: String,
      isAdmin: Bool,
      authMethod: AuthenticationMethod = .basicAuth,
      createdAt: Date = Date(),
      lastUsedAt: Date = Date(),
      seriesLastSyncedAt: Date = Date(timeIntervalSince1970: 0),
      booksLastSyncedAt: Date = Date(timeIntervalSince1970: 0)
    ) {
      self.id = id
      self.name = name
      self.serverURL = serverURL
      self.username = username
      self.authToken = authToken
      self.isAdmin = isAdmin
      self.authMethod = authMethod
      self.createdAt = createdAt
      self.lastUsedAt = lastUsedAt
      self.seriesLastSyncedAt = seriesLastSyncedAt
      self.booksLastSyncedAt = booksLastSyncedAt
    }
  }

  @Model
  final class KomgaLibrary {
    static let allLibrariesId = "__all_libraries__"

    @Attribute(.unique) var id: UUID
    var instanceId: String
    var libraryId: String
    var name: String
    var createdAt: Date

    // Metrics
    var fileSize: Double?
    var booksCount: Double?
    var seriesCount: Double?
    var sidecarsCount: Double?
    var collectionsCount: Double?
    var readlistsCount: Double?

    init(
      id: UUID = UUID(),
      instanceId: String,
      libraryId: String,
      name: String,
      createdAt: Date = Date(),
      fileSize: Double? = nil,
      booksCount: Double? = nil,
      seriesCount: Double? = nil,
      sidecarsCount: Double? = nil,
      collectionsCount: Double? = nil,
      readlistsCount: Double? = nil
    ) {
      self.id = id
      self.instanceId = instanceId
      self.libraryId = libraryId
      self.name = name
      self.createdAt = createdAt
      self.fileSize = fileSize
      self.booksCount = booksCount
      self.seriesCount = seriesCount
      self.sidecarsCount = sidecarsCount
      self.collectionsCount = collectionsCount
      self.readlistsCount = readlistsCount
    }
  }

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

    // API-aligned raw storage
    var metadataRaw: Data?
    var booksMetadataRaw: Data?

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

      self.metadataRaw = RawCodableStore.encode(metadata)
      self.booksMetadataRaw = RawCodableStore.encode(booksMetadata)
      self.metaTitle = metadata.title
      self.metaTitleSort = metadata.titleSort
      self.metaPublisherIndex = MetadataIndex.encode(value: metadata.publisher)
      self.metaAuthorsIndex = MetadataIndex.encode(values: booksMetadata.authors?.map(\.name) ?? [])
      self.metaGenresIndex = MetadataIndex.encode(values: metadata.genres ?? [])
      self.metaTagsIndex = MetadataIndex.encode(values: metadata.tags ?? [])
      self.metaLanguageIndex = MetadataIndex.encode(value: metadata.language)

      self.isUnavailable = isUnavailable
      self.oneshot = oneshot
      self.downloadedBooks = downloadedBooks
      self.pendingBooks = pendingBooks
      self.downloadedSize = downloadedSize
      self.offlinePolicyRaw = offlinePolicy.rawValue
      self.offlinePolicyLimit = offlinePolicyLimit
      self.collectionIdsRaw = try? JSONEncoder().encode([] as [String])
    }
  }

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

    // API-aligned raw storage
    var mediaRaw: Data?
    var metadataRaw: Data?
    var readProgressRaw: Data?

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
    var pageRotationsRaw: Data?
    var epubPreferencesRaw: String?

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

      self.mediaRaw = RawCodableStore.encode(media)
      self.metadataRaw = RawCodableStore.encode(metadata)
      self.readProgressRaw = RawCodableStore.encodeOptional(readProgress)

      self.mediaPagesCount = media.pagesCount
      self.mediaProfile = media.mediaProfile
      self.metaTitle = metadata.title
      self.metaNumber = metadata.number
      self.metaNumberSort = metadata.numberSort
      self.metaReleaseDate = metadata.releaseDate
      self.progressPage = readProgress?.page
      self.progressCompleted = readProgress?.completed
      self.progressReadDate = readProgress?.readDate
      self.metaAuthorsIndex = MetadataIndex.encode(values: metadata.authors?.map(\.name) ?? [])
      self.metaTagsIndex = MetadataIndex.encode(values: metadata.tags ?? [])

      self.seriesTitle = seriesTitle
      self.isUnavailable = isUnavailable
      self.oneshot = oneshot
      self.downloadedSize = downloadedSize
      self.readListIdsRaw = try? JSONEncoder().encode([] as [String])
      self.isolatePagesRaw = try? JSONEncoder().encode([] as [Int])
      self.pageRotationsRaw = nil
      self.epubPreferencesRaw = nil
      self.epubProgressionRaw = nil
    }
  }

  @Model
  final class KomgaCollection {
    @Attribute(.unique) var id: String  // Composite: CompositeID.generate

    var collectionId: String
    var instanceId: String

    var name: String
    var ordered: Bool
    var createdDate: Date
    var lastModifiedDate: Date
    var filtered: Bool
    var isPinned: Bool = false

    var seriesIdsRaw: Data?

    init(
      id: String? = nil,
      collectionId: String,
      instanceId: String,
      name: String,
      ordered: Bool,
      createdDate: Date,
      lastModifiedDate: Date,
      filtered: Bool,
      isPinned: Bool = false,
      seriesIds: [String] = []
    ) {
      self.id = id ?? CompositeID.generate(instanceId: instanceId, id: collectionId)
      self.collectionId = collectionId
      self.instanceId = instanceId
      self.name = name
      self.ordered = ordered
      self.createdDate = createdDate
      self.lastModifiedDate = lastModifiedDate
      self.filtered = filtered
      self.isPinned = isPinned
      self.seriesIdsRaw = try? JSONEncoder().encode(seriesIds)
    }
  }

  @Model
  final class KomgaReadList {
    @Attribute(.unique) var id: String  // Composite: CompositeID.generate

    var readListId: String
    var instanceId: String

    var name: String
    var summary: String
    var ordered: Bool
    var createdDate: Date
    var lastModifiedDate: Date
    var filtered: Bool
    var isPinned: Bool = false

    var bookIdsRaw: Data?

    // Track offline download status (managed locally, manual only)
    var downloadStatusRaw: String = "notDownloaded"
    var downloadError: String?
    var downloadAt: Date?
    var downloadedSize: Int64 = 0
    var downloadedBooks: Int = 0
    var pendingBooks: Int = 0

    init(
      id: String? = nil,
      readListId: String,
      instanceId: String,
      name: String,
      summary: String,
      ordered: Bool,
      createdDate: Date,
      lastModifiedDate: Date,
      filtered: Bool,
      isPinned: Bool = false,
      bookIds: [String] = [],
      downloadedBooks: Int = 0,
      pendingBooks: Int = 0,
      downloadedSize: Int64 = 0
    ) {
      self.id = id ?? CompositeID.generate(instanceId: instanceId, id: readListId)
      self.readListId = readListId
      self.instanceId = instanceId
      self.name = name
      self.summary = summary
      self.ordered = ordered
      self.createdDate = createdDate
      self.lastModifiedDate = lastModifiedDate
      self.filtered = filtered
      self.isPinned = isPinned
      self.bookIdsRaw = try? JSONEncoder().encode(bookIds)
      self.downloadedBooks = downloadedBooks
      self.pendingBooks = pendingBooks
      self.downloadedSize = downloadedSize
    }
  }

  @Model
  final class CustomFontV1 {
    @Attribute(.unique) var name: String
    var path: String?  // File path for imported fonts, nil for system/manual fonts
    var fileName: String?  // Original file name for imported fonts
    var fileSize: Int64?  // File size in bytes for imported fonts
    var createdAt: Date

    init(name: String, path: String? = nil, fileName: String? = nil, fileSize: Int64? = nil, createdAt: Date = Date()) {
      self.name = name
      self.path = path
      self.fileName = fileName
      self.fileSize = fileSize
      self.createdAt = createdAt
    }
  }

  @Model
  final class PendingProgress {
    @Attribute(.unique) var id: String  // Composite: "instanceId_bookId"

    var instanceId: String
    var bookId: String
    var page: Int
    var completed: Bool
    var createdAt: Date
    var progressionData: Data?  // For EPUB R2Progression

    init(
      instanceId: String,
      bookId: String,
      page: Int,
      completed: Bool,
      progressionData: Data? = nil
    ) {
      self.id = CompositeID.generate(instanceId: instanceId, id: bookId)
      self.instanceId = instanceId
      self.bookId = bookId
      self.page = page
      self.completed = completed
      self.createdAt = Date()
      self.progressionData = progressionData
    }
  }

  @Model
  final class SavedFilterV1 {
    @Attribute(.unique) var id: UUID

    var name: String
    var filterTypeRaw: String
    var filterDataJSON: String
    var createdAt: Date
    var updatedAt: Date

    init(
      id: UUID = UUID(),
      name: String,
      filterType: SavedFilterType,
      filterDataJSON: String,
      createdAt: Date = Date(),
      updatedAt: Date = Date()
    ) {
      self.id = id
      self.name = name
      self.filterTypeRaw = filterType.rawValue
      self.filterDataJSON = filterDataJSON
      self.createdAt = createdAt
      self.updatedAt = updatedAt
    }
  }

  @Model
  final class EpubThemePresetV1 {
    @Attribute(.unique) var id: UUID

    var name: String
    var preferencesJSON: String
    var createdAt: Date
    var updatedAt: Date

    init(
      id: UUID = UUID(),
      name: String,
      preferencesJSON: String,
      createdAt: Date = Date(),
      updatedAt: Date = Date()
    ) {
      self.id = id
      self.name = name
      self.preferencesJSON = preferencesJSON
      self.createdAt = createdAt
      self.updatedAt = updatedAt
    }
  }
}
