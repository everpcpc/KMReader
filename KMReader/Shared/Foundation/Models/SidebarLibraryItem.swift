//
// SidebarLibraryItem.swift
//
//

import Foundation

nonisolated struct SidebarLibraryItem: Hashable, Identifiable, Sendable {
  let id: String
  let libraryId: String
  let name: String
  let fileSize: Double?
  let booksCount: Double?
  let seriesCount: Double?
  let sidecarsCount: Double?
  let collectionsCount: Double?
  let readlistsCount: Double?

  init(
    libraryId: String,
    name: String,
    fileSize: Double?,
    booksCount: Double?,
    seriesCount: Double?,
    sidecarsCount: Double?,
    collectionsCount: Double?,
    readlistsCount: Double?
  ) {
    id = libraryId
    self.libraryId = libraryId
    self.name = name
    self.fileSize = fileSize
    self.booksCount = booksCount
    self.seriesCount = seriesCount
    self.sidecarsCount = sidecarsCount
    self.collectionsCount = collectionsCount
    self.readlistsCount = readlistsCount
  }

  var displayBookCount: Int? {
    booksCount.map { Int($0) }
  }
}
