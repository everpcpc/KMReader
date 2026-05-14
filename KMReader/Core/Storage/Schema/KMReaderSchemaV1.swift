//
// KMReaderSchemaV1.swift
//
//

import Foundation
import SwiftData

enum KMReaderSchemaV1: VersionedSchema {
  static var versionIdentifier: Schema.Version {
    Schema.Version(1, 0, 0)
  }

  static var models: [any PersistentModel.Type] {
    [
      KMReaderSchemaV1.KomgaInstance.self,
      KMReaderSchemaV1.KomgaLibrary.self,
      KMReaderSchemaV1.KomgaSeries.self,
      KMReaderSchemaV1.KomgaBook.self,
      KMReaderSchemaV1.KomgaCollection.self,
      KMReaderSchemaV1.KomgaReadList.self,
      KMReaderSchemaV1.CustomFont.self,
      KMReaderSchemaV1.PendingProgress.self,
      KMReaderSchemaV1.SavedFilter.self,
      KMReaderSchemaV1.EpubThemePreset.self,
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

    var mediaStatus: String = ""
    var mediaType: String = ""
    var mediaPagesCount: Int = 0
    var mediaComment: String?
    var mediaProfile: String?
    var mediaEpubDivinaCompatible: Bool?
    var mediaEpubIsKepub: Bool?

    var metaCreated: String?
    var metaLastModified: String?
    var metaTitle: String = ""
    var metaTitleLock: Bool?
    var metaSummary: String?
    var metaSummaryLock: Bool?
    var metaNumber: String = ""
    var metaNumberLock: Bool?
    var metaNumberSort: Double = 0
    var metaNumberSortLock: Bool?
    var metaReleaseDate: String?
    var metaReleaseDateLock: Bool?
    var metaAuthorsRaw: Data?
    var metaAuthorsLock: Bool?
    var metaTagsRaw: Data?
    var metaTagsLock: Bool?
    var metaIsbn: String?
    var metaIsbnLock: Bool?
    var metaLinksRaw: Data?
    var metaLinksLock: Bool?

    var progressPage: Int?
    var progressCompleted: Bool?
    var progressReadDate: Date?
    var progressCreated: Date?
    var progressLastModified: Date?

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

    var metaStatus: String?
    var metaStatusLock: Bool?
    var metaCreated: String?
    var metaLastModified: String?
    var metaTitle: String = ""
    var metaTitleLock: Bool?
    var metaTitleSort: String = ""
    var metaTitleSortLock: Bool?
    var metaSummary: String?
    var metaSummaryLock: Bool?
    var metaReadingDirection: String?
    var metaReadingDirectionLock: Bool?
    var metaPublisher: String?
    var metaPublisherLock: Bool?
    var metaAgeRating: Int?
    var metaAgeRatingLock: Bool?
    var metaLanguage: String?
    var metaLanguageLock: Bool?
    var metaGenresRaw: Data?
    var metaGenresLock: Bool?
    var metaTagsRaw: Data?
    var metaTagsLock: Bool?
    var metaTotalBookCount: Int?
    var metaTotalBookCountLock: Bool?
    var metaSharingLabelsRaw: Data?
    var metaSharingLabelsLock: Bool?
    var metaLinksRaw: Data?
    var metaLinksLock: Bool?
    var metaAlternateTitlesRaw: Data?
    var metaAlternateTitlesLock: Bool?

    var booksMetaCreated: String?
    var booksMetaLastModified: String?
    var booksMetaAuthorsRaw: Data?
    var booksMetaTagsRaw: Data?
    var booksMetaReleaseDate: String?
    var booksMetaSummary: String?
    var booksMetaSummaryNumber: String?

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
