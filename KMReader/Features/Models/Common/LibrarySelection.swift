//
//  LibrarySelection.swift
//  KMReader
//
//  Created by Komga iOS Client
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

  init(library: KomgaLibrary) {
    libraryId = library.libraryId
    name = library.name
    fileSize = library.fileSize
    booksCount = library.booksCount
    seriesCount = library.seriesCount
    collectionsCount = library.collectionsCount
    readlistsCount = library.readlistsCount
  }
}
