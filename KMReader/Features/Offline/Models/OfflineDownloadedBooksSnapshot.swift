//
// OfflineDownloadedBooksSnapshot.swift
//
//

import Foundation

nonisolated struct OfflineDownloadedBookItem: Equatable, Identifiable, Sendable {
  let id: String
  let instanceId: String
  let bookId: String
  let seriesId: String
  let libraryId: String
  let bookName: String
  let seriesTitle: String
  let metaNumber: String
  let metaTitle: String
  let metaNumberSort: Double
  let downloadedSize: Int64
  let isReadCompleted: Bool

  var listTitle: String {
    "#\(metaNumber) - \(metaTitle)"
  }

  var oneshotTitle: String {
    metaTitle.isEmpty ? bookName : metaTitle
  }
}

nonisolated struct OfflineDownloadedSeriesGroup: Equatable, Identifiable, Sendable {
  let id: String
  let name: String?
  let books: [OfflineDownloadedBookItem]

  var downloadedSize: Int64 {
    books.reduce(0) { $0 + $1.downloadedSize }
  }
}

nonisolated struct OfflineDownloadedLibraryGroup: Equatable, Identifiable, Sendable {
  let id: String
  let name: String?
  let seriesGroups: [OfflineDownloadedSeriesGroup]
  let oneshotBooks: [OfflineDownloadedBookItem]

  var downloadedSize: Int64 {
    let seriesSize = seriesGroups.reduce(0) { $0 + $1.downloadedSize }
    let oneshotSize = oneshotBooks.reduce(0) { $0 + $1.downloadedSize }
    return seriesSize + oneshotSize
  }
}

nonisolated struct OfflineDownloadedBooksSnapshot: Equatable, Sendable {
  let libraryGroups: [OfflineDownloadedLibraryGroup]

  static let empty = OfflineDownloadedBooksSnapshot(libraryGroups: [])

  var isEmpty: Bool {
    libraryGroups.allSatisfy { $0.seriesGroups.isEmpty && $0.oneshotBooks.isEmpty }
  }

  var totalDownloadedSize: Int64 {
    libraryGroups.reduce(0) { $0 + $1.downloadedSize }
  }

  var hasReadBooks: Bool {
    libraryGroups.contains { libraryGroup in
      libraryGroup.oneshotBooks.contains { $0.isReadCompleted }
        || libraryGroup.seriesGroups.contains { seriesGroup in
          seriesGroup.books.contains { $0.isReadCompleted }
        }
    }
  }
}
