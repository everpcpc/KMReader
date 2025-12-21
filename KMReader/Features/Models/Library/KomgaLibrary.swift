//
//  KomgaLibrary.swift
//  KMReader
//
//  Created by Komga iOS Client
//

import Foundation
import SwiftData

@Model
final class KomgaLibrary {
  static let allLibrariesId = "__all_libraries__"

  @Attribute(.unique) var id: UUID
  var instanceId: String
  var libraryId: String
  var name: String
  var createdAt: Date

  // Metrics
  var fileSize: Double?
  var booksCount: Double?
  var seriesCount: Double?
  var sidecarsCount: Double?
  var collectionsCount: Double?
  var readlistsCount: Double?

  init(
    id: UUID = UUID(),
    instanceId: String,
    libraryId: String,
    name: String,
    createdAt: Date = Date(),
    fileSize: Double? = nil,
    booksCount: Double? = nil,
    seriesCount: Double? = nil,
    sidecarsCount: Double? = nil,
    collectionsCount: Double? = nil,
    readlistsCount: Double? = nil
  ) {
    self.id = id
    self.instanceId = instanceId
    self.libraryId = libraryId
    self.name = name
    self.createdAt = createdAt
    self.fileSize = fileSize
    self.booksCount = booksCount
    self.seriesCount = seriesCount
    self.sidecarsCount = sidecarsCount
    self.collectionsCount = collectionsCount
    self.readlistsCount = readlistsCount
  }
}
