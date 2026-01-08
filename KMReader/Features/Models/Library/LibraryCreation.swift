//
//  LibraryCreation.swift
//  KMReader
//
//  Created by Komga iOS Client
//

import Foundation

/// Scan interval options for library scanning
enum ScanInterval: String, Codable, CaseIterable, Identifiable {
  case disabled = "DISABLED"
  case hourly = "HOURLY"
  case every6h = "EVERY_6H"
  case every12h = "EVERY_12H"
  case daily = "DAILY"
  case weekly = "WEEKLY"

  var id: String { rawValue }

  var localizedName: String {
    switch self {
    case .disabled: return String(localized: "Disabled")
    case .hourly: return String(localized: "Hourly")
    case .every6h: return String(localized: "Every 6 hours")
    case .every12h: return String(localized: "Every 12 hours")
    case .daily: return String(localized: "Daily")
    case .weekly: return String(localized: "Weekly")
    }
  }
}

/// Series cover selection mode
enum SeriesCoverMode: String, Codable, CaseIterable, Identifiable {
  case first = "FIRST"
  case firstUnreadOrFirst = "FIRST_UNREAD_OR_FIRST"
  case firstUnreadOrLast = "FIRST_UNREAD_OR_LAST"
  case last = "LAST"

  var id: String { rawValue }

  var localizedName: String {
    switch self {
    case .first: return String(localized: "First")
    case .firstUnreadOrFirst: return String(localized: "First Unread or First")
    case .firstUnreadOrLast: return String(localized: "First Unread or Last")
    case .last: return String(localized: "Last")
    }
  }
}

/// Request body for creating a new library
struct LibraryCreation: Codable {
  // General
  var name: String
  var root: String

  // Scanner settings
  var emptyTrashAfterScan: Bool
  var scanForceModifiedTime: Bool
  var scanOnStartup: Bool
  var scanInterval: ScanInterval
  var scanCbx: Bool
  var scanPdf: Bool
  var scanEpub: Bool
  var scanDirectoryExclusions: [String]
  var oneshotsDirectory: String

  // Options
  var hashFiles: Bool
  var hashPages: Bool
  var hashKoreader: Bool
  var analyzeDimensions: Bool
  var repairExtensions: Bool
  var convertToCbz: Bool
  var seriesCover: SeriesCoverMode

  // Metadata
  var importComicInfoBook: Bool
  var importComicInfoSeries: Bool
  var importComicInfoCollection: Bool
  var importComicInfoReadList: Bool
  var importComicInfoSeriesAppendVolume: Bool
  var importEpubBook: Bool
  var importEpubSeries: Bool
  var importMylarSeries: Bool
  var importLocalArtwork: Bool
  var importBarcodeIsbn: Bool

  /// Create a new LibraryCreation with default values
  static func createDefault(name: String = "", root: String = "") -> LibraryCreation {
    LibraryCreation(
      name: name,
      root: root,
      emptyTrashAfterScan: false,
      scanForceModifiedTime: false,
      scanOnStartup: false,
      scanInterval: .every6h,
      scanCbx: true,
      scanPdf: true,
      scanEpub: true,
      scanDirectoryExclusions: ["#recycle", "@eaDir", "@Recycle"],
      oneshotsDirectory: "",
      hashFiles: true,
      hashPages: false,
      hashKoreader: false,
      analyzeDimensions: true,
      repairExtensions: false,
      convertToCbz: false,
      seriesCover: .first,
      importComicInfoBook: true,
      importComicInfoSeries: true,
      importComicInfoCollection: true,
      importComicInfoReadList: true,
      importComicInfoSeriesAppendVolume: true,
      importEpubBook: true,
      importEpubSeries: true,
      importMylarSeries: true,
      importLocalArtwork: true,
      importBarcodeIsbn: false
    )
  }
}
