//
// KMReaderSchemaV2.swift
//
//

import Foundation
import SwiftData

enum KMReaderSchemaV2: VersionedSchema {
  static var versionIdentifier: Schema.Version {
    Schema.Version(2, 0, 0)
  }

  static var models: [any PersistentModel.Type] {
    [
      KMReaderSchemaV2.KomgaInstance.self,
      KMReaderSchemaV2.KomgaLibrary.self,
      KMReaderSchemaV2.KomgaSeries.self,
      KMReaderSchemaV2.KomgaBook.self,
      KMReaderSchemaV2.KomgaCollection.self,
      KMReaderSchemaV2.KomgaReadList.self,
      KMReaderSchemaV2.CustomFont.self,
      KMReaderSchemaV2.PendingProgress.self,
      KMReaderSchemaV2.SavedFilter.self,
      KMReaderSchemaV2.EpubThemePreset.self,
    ]
  }

  @Model
  final class KomgaInstance {
    @Attribute(.unique) var id: UUID = UUID()
    var name: String = ""
    var serverURL: String = ""
    var username: String = ""
    var authToken: String = ""
    var isAdmin: Bool = false
    var authMethod: AuthenticationMethod? = AuthenticationMethod.basicAuth
    var createdAt: Date = Date(timeIntervalSince1970: 0)
    var lastUsedAt: Date = Date(timeIntervalSince1970: 0)
    var seriesLastSyncedAt: Date = Date(timeIntervalSince1970: 0)
    var booksLastSyncedAt: Date = Date(timeIntervalSince1970: 0)

    init() {}
  }

  @Model
  final class KomgaLibrary {
    @Attribute(.unique) var id: UUID = UUID()
    var instanceId: String = ""
    var libraryId: String = ""
    var name: String = ""
    var createdAt: Date = Date(timeIntervalSince1970: 0)

    var fileSize: Double?
    var booksCount: Double?
    var seriesCount: Double?
    var sidecarsCount: Double?
    var collectionsCount: Double?
    var readlistsCount: Double?

    init() {}
  }

  @Model
  final class KomgaBook {
    @Attribute(.unique) var id: String = ""

    var bookId: String = ""
    var seriesId: String = ""
    var libraryId: String = ""
    var instanceId: String = ""

    var name: String = ""
    var url: String = ""
    var number: Double = 0
    var created: Date = Date(timeIntervalSince1970: 0)
    var lastModified: Date = Date(timeIntervalSince1970: 0)
    var sizeBytes: Int64 = 0
    var size: String = ""

    var media: Media?
    var metadata: BookMetadata?
    var readProgress: ReadProgress?

    var mediaPagesCount: Int = 0
    var mediaProfile: String?
    var metaTitle: String = ""
    var metaNumber: String = ""
    var metaNumberSort: Double = 0
    var metaReleaseDate: String?
    var progressPage: Int?
    var progressCompleted: Bool?
    var progressReadDate: Date?
    var metaAuthorsIndex: String = "|"
    var metaTagsIndex: String = "|"

    var isUnavailable: Bool = false
    var oneshot: Bool = false
    var seriesTitle: String = ""

    var pagesRaw: Data?
    var tocRaw: Data?
    var webPubManifestRaw: Data?
    var epubProgressionRaw: Data?

    var downloadStatusRaw: String = "notDownloaded"
    var downloadError: String?
    var downloadAt: Date?
    var downloadedSize: Int64 = 0

    var readListIdsRaw: Data?

    var isolatePagesRaw: Data?
    var epubPreferencesRaw: String?

    init() {}

    func applyContent(media: Media, metadata: BookMetadata, readProgress: ReadProgress?) {
      self.media = media
      self.metadata = metadata
      self.readProgress = readProgress
      mediaPagesCount = media.pagesCount
      mediaProfile = media.mediaProfile
      metaTitle = metadata.title
      metaNumber = metadata.number
      metaNumberSort = metadata.numberSort
      metaReleaseDate = metadata.releaseDate
      progressPage = readProgress?.page
      progressCompleted = readProgress?.completed
      progressReadDate = readProgress?.readDate
      metaAuthorsIndex = MetadataIndex.encode(values: metadata.authors?.map(\.name) ?? [])
      metaTagsIndex = MetadataIndex.encode(values: metadata.tags ?? [])
    }
  }

  @Model
  final class KomgaSeries {
    @Attribute(.unique) var id: String = ""

    var seriesId: String = ""
    var libraryId: String = ""
    var instanceId: String = ""

    var name: String = ""
    var url: String = ""
    var created: Date = Date(timeIntervalSince1970: 0)
    var lastModified: Date = Date(timeIntervalSince1970: 0)

    var booksCount: Int = 0
    var booksReadCount: Int = 0
    var booksUnreadCount: Int = 0
    var booksInProgressCount: Int = 0

    var metadata: SeriesMetadata?
    var booksMetadata: SeriesBooksMetadata?

    var metaTitle: String = ""
    var metaTitleSort: String = ""
    var metaPublisherIndex: String = "|"
    var metaAuthorsIndex: String = "|"
    var metaGenresIndex: String = "|"
    var metaTagsIndex: String = "|"
    var metaLanguageIndex: String = "|"

    var isUnavailable: Bool = false
    var oneshot: Bool = false

    var downloadStatusRaw: String = "notDownloaded"
    var downloadError: String?
    var downloadAt: Date?
    var downloadedSize: Int64 = 0
    var downloadedBooks: Int = 0
    var pendingBooks: Int = 0
    var offlinePolicyRaw: String = "manual"
    var offlinePolicyLimit: Int = 0

    var collectionIdsRaw: Data?

    init() {}

    func applyContent(metadata: SeriesMetadata, booksMetadata: SeriesBooksMetadata) {
      self.metadata = metadata
      self.booksMetadata = booksMetadata
      metaTitle = metadata.title
      metaTitleSort = metadata.titleSort
      metaPublisherIndex = MetadataIndex.encode(value: metadata.publisher)
      metaAuthorsIndex = MetadataIndex.encode(values: booksMetadata.authors?.map(\.name) ?? [])
      metaGenresIndex = MetadataIndex.encode(values: metadata.genres ?? [])
      metaTagsIndex = MetadataIndex.encode(values: metadata.tags ?? [])
      metaLanguageIndex = MetadataIndex.encode(value: metadata.language)
    }
  }

  @Model
  final class KomgaCollection {
    @Attribute(.unique) var id: String = ""

    var collectionId: String = ""
    var instanceId: String = ""

    var name: String = ""
    var ordered: Bool = false
    var createdDate: Date = Date(timeIntervalSince1970: 0)
    var lastModifiedDate: Date = Date(timeIntervalSince1970: 0)
    var filtered: Bool = false

    var seriesIdsRaw: Data?

    init() {}
  }

  @Model
  final class KomgaReadList {
    @Attribute(.unique) var id: String = ""

    var readListId: String = ""
    var instanceId: String = ""

    var name: String = ""
    var summary: String = ""
    var ordered: Bool = false
    var createdDate: Date = Date(timeIntervalSince1970: 0)
    var lastModifiedDate: Date = Date(timeIntervalSince1970: 0)
    var filtered: Bool = false

    var bookIdsRaw: Data?

    var downloadStatusRaw: String = "notDownloaded"
    var downloadError: String?
    var downloadAt: Date?
    var downloadedSize: Int64 = 0
    var downloadedBooks: Int = 0
    var pendingBooks: Int = 0

    init() {}
  }

  @Model
  final class CustomFont {
    @Attribute(.unique) var name: String = ""
    var path: String?
    var fileName: String?
    var fileSize: Int64?
    var createdAt: Date = Date(timeIntervalSince1970: 0)

    init() {}
  }

  @Model
  final class PendingProgress {
    @Attribute(.unique) var id: String = ""
    var instanceId: String = ""
    var bookId: String = ""
    var page: Int = 0
    var completed: Bool = false
    var createdAt: Date = Date(timeIntervalSince1970: 0)
    var progressionData: Data?

    init() {}
  }

  @Model
  final class SavedFilter {
    @Attribute(.unique) var id: UUID = UUID()
    var name: String = ""
    var filterTypeRaw: String = ""
    var filterDataJSON: String = ""
    var createdAt: Date = Date(timeIntervalSince1970: 0)
    var updatedAt: Date = Date(timeIntervalSince1970: 0)

    init() {}
  }

  @Model
  final class EpubThemePreset {
    @Attribute(.unique) var id: UUID = UUID()
    var name: String = ""
    var preferencesJSON: String = ""
    var createdAt: Date = Date(timeIntervalSince1970: 0)
    var updatedAt: Date = Date(timeIntervalSince1970: 0)

    init() {}
  }
}
