//
//  LibraryUpdate.swift
//  KMReader
//
//  Created by Komga iOS Client
//

import Foundation

/// Request body for updating an existing library
struct LibraryUpdate: Codable {
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

  /// Create a LibraryUpdate from an existing Library
  static func from(_ library: Library) -> LibraryUpdate {
    LibraryUpdate(
      name: library.name,
      root: library.root,
      emptyTrashAfterScan: library.emptyTrashAfterScan ?? false,
      scanForceModifiedTime: library.scanForceModifiedTime ?? false,
      scanOnStartup: library.scanOnStartup ?? false,
      scanInterval: ScanInterval(rawValue: library.scanInterval ?? "EVERY_6H") ?? .every6h,
      scanCbx: library.scanCbx ?? true,
      scanPdf: library.scanPdf ?? true,
      scanEpub: library.scanEpub ?? true,
      scanDirectoryExclusions: library.scanDirectoryExclusions ?? [],
      oneshotsDirectory: library.oneshotsDirectory ?? "",
      hashFiles: library.hashFiles ?? true,
      hashPages: library.hashPages ?? false,
      hashKoreader: library.hashKoreader ?? false,
      analyzeDimensions: library.analyzeDimensions ?? true,
      repairExtensions: library.repairExtensions ?? false,
      convertToCbz: library.convertToCbz ?? false,
      seriesCover: SeriesCoverMode(rawValue: library.seriesCover ?? "FIRST") ?? .first,
      importComicInfoBook: library.importComicInfoBook ?? true,
      importComicInfoSeries: library.importComicInfoSeries ?? true,
      importComicInfoCollection: library.importComicInfoCollection ?? true,
      importComicInfoReadList: library.importComicInfoReadList ?? true,
      importComicInfoSeriesAppendVolume: library.importComicInfoSeriesAppendVolume ?? true,
      importEpubBook: library.importEpubBook ?? true,
      importEpubSeries: library.importEpubSeries ?? true,
      importMylarSeries: library.importMylarSeries ?? true,
      importLocalArtwork: library.importLocalArtwork ?? true,
      importBarcodeIsbn: library.importBarcodeIsbn ?? false
    )
  }
}
