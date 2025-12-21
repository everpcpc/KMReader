//
//  KomgaReadList.swift
//  KMReader
//
//  Created by Komga iOS Client
//

import Foundation
import SwiftData

@Model
final class KomgaReadList {
  @Attribute(.unique) var id: String  // Composite ID: "\(instanceId)_\(readListId)"

  var readListId: String
  var instanceId: String

  var name: String
  var summary: String
  var ordered: Bool
  var createdDate: Date
  var lastModifiedDate: Date
  var filtered: Bool

  var bookIds: [String] = []

  init(
    id: String? = nil,
    readListId: String,
    instanceId: String,
    name: String,
    summary: String,
    ordered: Bool,
    createdDate: Date,
    lastModifiedDate: Date,
    filtered: Bool,
    bookIds: [String] = []
  ) {
    self.id = id ?? "\(instanceId)_\(readListId)"
    self.readListId = readListId
    self.instanceId = instanceId
    self.name = name
    self.summary = summary
    self.ordered = ordered
    self.createdDate = createdDate
    self.lastModifiedDate = lastModifiedDate
    self.filtered = filtered
    self.bookIds = bookIds
  }

  func toReadList() -> ReadList {
    ReadList(
      id: readListId,
      name: name,
      summary: summary,
      ordered: ordered,
      bookIds: bookIds,
      createdDate: createdDate,
      lastModifiedDate: lastModifiedDate,
      filtered: filtered
    )
  }
}
