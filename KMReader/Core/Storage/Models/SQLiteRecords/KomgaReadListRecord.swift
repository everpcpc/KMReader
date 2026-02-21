//
// KomgaReadListRecord.swift
//
//

import Foundation
import SQLiteData

@Table("komga_read_lists")
nonisolated struct KomgaReadListRecord: Identifiable, Hashable, Sendable {
  let id: String

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
    self.id = id ?? UUID().uuidString
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

  func toKomgaReadList(localState: KomgaReadListLocalStateRecord? = nil) -> KomgaReadList {
    let state = localState ?? .empty(instanceId: instanceId, readListId: readListId)
    let legacy = KomgaReadList(
      id: id,
      readListId: readListId,
      instanceId: instanceId,
      name: name,
      summary: summary,
      ordered: ordered,
      createdDate: createdDate,
      lastModifiedDate: lastModifiedDate,
      filtered: filtered,
      bookIds: bookIds,
      downloadedBooks: state.downloadedBooks,
      pendingBooks: state.pendingBooks,
      downloadedSize: state.downloadedSize
    )
    legacy.downloadStatusRaw = state.downloadStatusRaw
    legacy.downloadError = state.downloadError
    legacy.downloadAt = state.downloadAt
    return legacy
  }
}
