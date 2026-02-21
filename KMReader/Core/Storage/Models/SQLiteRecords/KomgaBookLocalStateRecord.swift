//
// KomgaBookLocalStateRecord.swift
//
//

import Foundation
import SQLiteData

@Table("komga_book_local_state")
nonisolated struct KomgaBookLocalStateRecord: Hashable, Sendable {
  var instanceId: String
  var bookId: String
  var pagesRaw: Data?
  var tocRaw: Data?
  var webPubManifestRaw: Data?
  var epubProgressionRaw: Data?
  var isolatePagesRaw: Data?
  var epubPreferencesRaw: String?
  var downloadStatusRaw: String = "notDownloaded"
  var downloadError: String?
  @Column(as: Date?.UnixTimeRepresentation.self)
  var downloadAt: Date?
  var downloadedSize: Int64 = 0
  var readListIdsRaw: Data?

  var pages: [BookPage]? {
    get {
      pagesRaw.flatMap { try? JSONDecoder().decode([BookPage].self, from: $0) }
    }
    set {
      pagesRaw = try? JSONEncoder().encode(newValue)
    }
  }

  var tableOfContents: [ReaderTOCEntry]? {
    get {
      tocRaw.flatMap { try? JSONDecoder().decode([ReaderTOCEntry].self, from: $0) }
    }
    set {
      tocRaw = try? JSONEncoder().encode(newValue)
    }
  }

  var isolatePages: [Int] {
    get {
      isolatePagesRaw.flatMap { try? JSONDecoder().decode([Int].self, from: $0) } ?? []
    }
    set {
      isolatePagesRaw = try? JSONEncoder().encode(newValue)
    }
  }

  var epubPreferences: EpubReaderPreferences? {
    get {
      epubPreferencesRaw.flatMap(EpubReaderPreferences.init(rawValue:))
    }
    set {
      epubPreferencesRaw = newValue?.rawValue
    }
  }

  var readListIds: [String] {
    get {
      readListIdsRaw.flatMap { try? JSONDecoder().decode([String].self, from: $0) } ?? []
    }
    set {
      readListIdsRaw = try? JSONEncoder().encode(newValue)
    }
  }

  var downloadStatus: DownloadStatus {
    get {
      switch downloadStatusRaw {
      case "pending", "downloading":
        return .pending
      case "downloaded":
        return .downloaded
      case "failed":
        return .failed(error: downloadError ?? "Unknown error")
      default:
        return .notDownloaded
      }
    }
    set {
      switch newValue {
      case .notDownloaded:
        downloadStatusRaw = "notDownloaded"
        downloadError = nil
        downloadAt = nil
      case .pending:
        downloadStatusRaw = "pending"
        downloadError = nil
      case .downloaded:
        downloadStatusRaw = "downloaded"
        downloadError = nil
      case .failed(let error):
        downloadStatusRaw = "failed"
        downloadError = error
      }
    }
  }

  static func empty(instanceId: String, bookId: String) -> KomgaBookLocalStateRecord {
    KomgaBookLocalStateRecord(
      instanceId: instanceId,
      bookId: bookId,
      pagesRaw: nil,
      tocRaw: nil,
      webPubManifestRaw: nil,
      epubProgressionRaw: nil,
      isolatePagesRaw: try? JSONEncoder().encode([] as [Int]),
      epubPreferencesRaw: nil,
      downloadStatusRaw: "notDownloaded",
      downloadError: nil,
      downloadAt: nil,
      downloadedSize: 0,
      readListIdsRaw: try? JSONEncoder().encode([] as [String])
    )
  }
}
