//
// KomgaReadListRecord.swift
//
//

import Foundation
import SQLiteData

@Table("komga_read_lists")
nonisolated struct KomgaReadListRecord: Hashable, Sendable {
  // API identifier (ReadListDto.id).
  var readListId: String
  var instanceId: String

  // API scalar fields.
  var name: String
  var summary: String
  var ordered: Bool
  @Column(as: Date.UnixTimeRepresentation.self)
  var createdDate: Date
  @Column(as: Date.UnixTimeRepresentation.self)
  var lastModifiedDate: Date
  var filtered: Bool

  // API array field persisted as JSON for SQLite storage.
  var bookIdsRaw: Data?

  var bookIds: [String] {
    get { bookIdsRaw.flatMap { try? JSONDecoder().decode([String].self, from: $0) } ?? [] }
    set { bookIdsRaw = try? JSONEncoder().encode(newValue) }
  }

  init(
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
    self.readListId = readListId
    self.instanceId = instanceId
    self.name = name
    self.summary = summary
    self.ordered = ordered
    self.createdDate = createdDate
    self.lastModifiedDate = lastModifiedDate
    self.filtered = filtered
    self.bookIdsRaw = try? JSONEncoder().encode(bookIds)
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
