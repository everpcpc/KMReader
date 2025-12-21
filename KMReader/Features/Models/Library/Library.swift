//
//  Library.swift
//  Komga
//
//  Created by Komga iOS Client
//

import Foundation

struct Library: Codable, Identifiable, Equatable {
  let id: String
  let name: String
  let root: String
  let importComicInfoBook: Bool?
  let importComicInfoSeries: Bool?
  let importComicInfoCollection: Bool?
  let importComicInfoReadList: Bool?
  let importComicInfoSeriesAppendVolume: Bool?
  let importEpubBook: Bool?
  let importEpubSeries: Bool?
  let importMylarSeries: Bool?
  let importLocalArtwork: Bool?
  let importBarcodeIsbn: Bool?
  let scanForceModifiedTime: Bool?
  let scanInterval: String?
  let scanOnStartup: Bool?
  let scanCbx: Bool?
  let scanPdf: Bool?
  let scanEpub: Bool?
  let scanDirectoryExclusions: [String]?
  let repairExtensions: Bool?
  let convertToCbz: Bool?
  let emptyTrashAfterScan: Bool?
  let seriesCover: String?
  let hashFiles: Bool?
  let hashPages: Bool?
  let hashKoreader: Bool?
  let analyzeDimensions: Bool?
  let oneshotsDirectory: String?
  let unavailable: Bool?
}
