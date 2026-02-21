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
      KomgaInstance.self,
      KomgaLibrary.self,
      KMReaderSchemaV1.KomgaSeries.self,
      KMReaderSchemaV1.KomgaBook.self,
      KomgaCollection.self,
      KomgaReadList.self,
      CustomFont.self,
      PendingProgress.self,
      SavedFilter.self,
      EpubThemePreset.self,
    ]
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
}
