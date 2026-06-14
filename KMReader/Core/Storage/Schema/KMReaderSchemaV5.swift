//
// KMReaderSchemaV5.swift
//
//

import Foundation
import SwiftData

enum KMReaderSchemaV5: VersionedSchema {
  static var versionIdentifier: Schema.Version {
    Schema.Version(5, 0, 0)
  }

  static var models: [any PersistentModel.Type] {
    [
      KMReaderSchemaV5.KomgaInstance.self,
      KMReaderSchemaV5.KomgaLibrary.self,
      KMReaderSchemaV5.KomgaSeries.self,
      KMReaderSchemaV5.KomgaBook.self,
      KMReaderSchemaV5.KomgaCollection.self,
      KMReaderSchemaV5.KomgaReadList.self,
      KMReaderSchemaV5.CustomFont.self,
      KMReaderSchemaV5.PendingProgress.self,
      KMReaderSchemaV5.SavedFilter.self,
      KMReaderSchemaV5.EpubThemePreset.self,
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

    // API-aligned raw storage
    var mediaRaw: Data?
    var metadataRaw: Data?
    var readProgressRaw: Data?

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
    var pageRotationsRaw: Data?
    var epubPreferencesRaw: String?

    init() {}
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

    // API-aligned raw storage
    var metadataRaw: Data?
    var booksMetadataRaw: Data?

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
    var isPinned: Bool = false

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
    var isPinned: Bool = false

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
