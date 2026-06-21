//
// ReadListDisplayItem.swift
//
//

import Foundation

nonisolated struct ReadListDisplayItem: Equatable, Identifiable, Sendable {
  let id: String
  let readListId: String
  let instanceId: String
  let name: String
  let summary: String
  let ordered: Bool
  let createdDate: Date
  let lastModifiedDate: Date
  let filtered: Bool
  let isPinned: Bool
  let bookIds: [String]
  let downloadStatus: SeriesDownloadStatus
  let offlinePolicy: OfflinePolicy
  let offlinePolicyLimit: Int

  init(
    readListId: String,
    instanceId: String,
    name: String,
    summary: String,
    ordered: Bool,
    createdDate: Date,
    lastModifiedDate: Date,
    filtered: Bool,
    isPinned: Bool,
    bookIds: [String],
    downloadStatus: SeriesDownloadStatus,
    offlinePolicy: OfflinePolicy,
    offlinePolicyLimit: Int
  ) {
    id = readListId
    self.readListId = readListId
    self.instanceId = instanceId
    self.name = name
    self.summary = summary
    self.ordered = ordered
    self.createdDate = createdDate
    self.lastModifiedDate = lastModifiedDate
    self.filtered = filtered
    self.isPinned = isPinned
    self.bookIds = bookIds
    self.downloadStatus = downloadStatus
    self.offlinePolicy = offlinePolicy
    self.offlinePolicyLimit = offlinePolicyLimit
  }

  var bookCount: Int {
    bookIds.count
  }

  var readList: ReadList {
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
