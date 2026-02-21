//
// LibrarySelection.swift
//
//

import Foundation

struct LibrarySelection: Hashable {
  let libraryId: String
  let name: String
  let fileSize: Double?
  let booksCount: Double?
  let seriesCount: Double?
  let collectionsCount: Double?
  let readlistsCount: Double?

  init(record: KomgaLibraryRecord) {
    libraryId = record.libraryId
    name = record.name
    fileSize = record.fileSize
    booksCount = record.booksCount
    seriesCount = record.seriesCount
    collectionsCount = record.collectionsCount
    readlistsCount = record.readlistsCount
  }
}
