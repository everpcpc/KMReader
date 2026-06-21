//
// DatabaseOperator+Collections.swift
//
//

import Foundation
import GRDB

extension DatabaseOperator {
  func fetchSidebarCollections(instanceId: String) throws -> [SidebarCollectionItem] {
    try read { db in
      try orderedCollections(db: db, instanceId: instanceId).map { collection in
        SidebarCollectionItem(
          collectionId: collection.collectionId,
          name: collection.name,
          seriesCount: collection.seriesIds.count
        )
      }
    }
  }

  func fetchSidebarCollections(instanceId: String, collectionIds: Set<String>) throws -> [SidebarCollectionItem] {
    try read { db in
      try orderedCollections(db: db, instanceId: instanceId)
        .filter { collectionIds.contains($0.collectionId) }
        .map { collection in
          SidebarCollectionItem(
            collectionId: collection.collectionId,
            name: collection.name,
            seriesCount: collection.seriesIds.count
          )
        }
    }
  }

  func fetchPinnedCollectionDisplayItems(instanceId: String) throws -> [CollectionDisplayItem] {
    try read { db in
      try orderedCollections(db: db, instanceId: instanceId)
        .filter(\.isPinned)
        .map(Self.makeCollectionDisplayItem)
    }
  }

  func fetchCollectionDisplayItems(instanceId: String) throws -> [CollectionDisplayItem] {
    try read { db in
      try orderedCollections(db: db, instanceId: instanceId).map(Self.makeCollectionDisplayItem)
    }
  }

  func fetchCollectionIds(
    instanceId: String,
    libraryIds: [String]?,
    searchText: String,
    sort: String?,
    offset: Int,
    limit: Int
  ) -> [String] {
    guard limit > 0 else { return [] }
    return
      (try? read { db in
        var sql = """
          SELECT collection_id
          FROM \(KomgaCollection.databaseTableName)
          WHERE instance_id = ?
          """
        var arguments: StatementArguments = [instanceId]
        let trimmedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedSearch.isEmpty {
          sql += "\nAND name LIKE ? ESCAPE char(92)"
          arguments += StatementArguments([Self.sqlContainsPattern(trimmedSearch)])
        }
        sql += "\nORDER BY is_pinned DESC, \(Self.collectionOrderSQL(sort: sort))"
        sql += "\nLIMIT ? OFFSET ?"
        arguments += StatementArguments([limit, max(0, offset)])
        return try String.fetchAll(
          db,
          sql: sql,
          arguments: arguments
        )
      }) ?? []
  }

  func fetchCollectionDisplayItem(collectionId: String, instanceId: String) throws -> CollectionDisplayItem? {
    try read { db in
      try fetchCollectionRecord(db: db, id: collectionId, instanceId: instanceId).map(Self.makeCollectionDisplayItem)
    }
  }

  func upsertCollection(dto: SeriesCollection, instanceId: String) {
    do {
      try write { db in
        let compositeId = CompositeID.generate(instanceId: instanceId, id: dto.id)
        if var existing = try KomgaCollection.fetchOne(db, key: compositeId) {
          applyCollection(dto: dto, to: &existing)
          try save(existing, db: db)
        } else {
          let collection = KomgaCollection(
            id: compositeId,
            collectionId: dto.id,
            instanceId: instanceId,
            name: dto.name,
            ordered: dto.ordered,
            createdDate: dto.createdDate,
            lastModifiedDate: dto.lastModifiedDate,
            filtered: dto.filtered,
            seriesIds: dto.seriesIds
          )
          try save(collection, db: db)
        }
      }
    } catch {
      logger.error("Failed to upsert collection: \(error)")
    }
  }

  func deleteCollection(id: String, instanceId: String) {
    _ = try? write { db in
      try KomgaCollection.deleteOne(db, key: CompositeID.generate(instanceId: instanceId, id: id))
    }
  }

  func setCollectionPinned(collectionId: String, instanceId: String, isPinned: Bool) {
    try? write { db in
      guard var collection = try fetchCollectionRecord(db: db, id: collectionId, instanceId: instanceId) else {
        return
      }
      collection.isPinned = isPinned
      try save(collection, db: db)
    }
  }

  func upsertCollections(_ collections: [SeriesCollection], instanceId: String) {
    do {
      try write { db in
        let existingCollections = try fetchCollections(db: db, instanceId: instanceId)
        let existingById = Dictionary(uniqueKeysWithValues: existingCollections.map { ($0.collectionId, $0) })
        for collection in collections {
          var record =
            existingById[collection.id]
            ?? KomgaCollection(
              id: CompositeID.generate(instanceId: instanceId, id: collection.id),
              collectionId: collection.id,
              instanceId: instanceId,
              name: collection.name,
              ordered: collection.ordered,
              createdDate: collection.createdDate,
              lastModifiedDate: collection.lastModifiedDate,
              filtered: collection.filtered,
              seriesIds: collection.seriesIds
            )
          applyCollection(dto: collection, to: &record)
          try save(record, db: db)
        }
      }
    } catch {
      logger.error("Failed to upsert collections: \(error)")
    }
  }

  func deleteCollectionsNotIn(_ collectionIds: Set<String>, instanceId: String) -> Int {
    (try? write { db in
      let existingCollections = try fetchCollections(db: db, instanceId: instanceId)
      var deletedCount = 0
      for collection in existingCollections where !collectionIds.contains(collection.collectionId) {
        try KomgaCollection.deleteOne(db, key: collection.id)
        deletedCount += 1
      }
      return deletedCount
    }) ?? 0
  }
}

extension DatabaseOperator {
  func fetchSidebarReadLists(instanceId: String) throws -> [SidebarReadListItem] {
    try read { db in
      try orderedReadLists(db: db, instanceId: instanceId).map { readList in
        SidebarReadListItem(
          readListId: readList.readListId,
          name: readList.name,
          bookCount: readList.bookIds.count
        )
      }
    }
  }

  func fetchSidebarReadLists(instanceId: String, readListIds: Set<String>) throws -> [SidebarReadListItem] {
    try read { db in
      try orderedReadLists(db: db, instanceId: instanceId)
        .filter { readListIds.contains($0.readListId) }
        .map { readList in
          SidebarReadListItem(
            readListId: readList.readListId,
            name: readList.name,
            bookCount: readList.bookIds.count
          )
        }
    }
  }

  func fetchPinnedReadListDisplayItems(instanceId: String) throws -> [ReadListDisplayItem] {
    try read { db in
      try orderedReadLists(db: db, instanceId: instanceId)
        .filter(\.isPinned)
        .map(Self.makeReadListDisplayItem)
    }
  }

  func fetchReadListDisplayItems(instanceId: String) throws -> [ReadListDisplayItem] {
    try read { db in
      try orderedReadLists(db: db, instanceId: instanceId).map(Self.makeReadListDisplayItem)
    }
  }

  func fetchReadListIds(
    instanceId: String,
    libraryIds: [String]?,
    searchText: String,
    sort: String?,
    offset: Int,
    limit: Int
  ) -> [String] {
    guard limit > 0 else { return [] }
    return
      (try? read { db in
        var sql = """
          SELECT read_list_id
          FROM \(KomgaReadList.databaseTableName)
          WHERE instance_id = ?
          """
        var arguments: StatementArguments = [instanceId]
        let trimmedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedSearch.isEmpty {
          let pattern = Self.sqlContainsPattern(trimmedSearch)
          sql += "\nAND (name LIKE ? ESCAPE char(92) OR summary LIKE ? ESCAPE char(92))"
          arguments += StatementArguments([pattern, pattern])
        }
        sql += "\nORDER BY is_pinned DESC, \(Self.readListOrderSQL(sort: sort))"
        sql += "\nLIMIT ? OFFSET ?"
        arguments += StatementArguments([limit, max(0, offset)])
        return try String.fetchAll(
          db,
          sql: sql,
          arguments: arguments
        )
      }) ?? []
  }

  func fetchReadListDisplayItem(readListId: String, instanceId: String) throws -> ReadListDisplayItem? {
    try read { db in
      try fetchReadListRecord(db: db, id: readListId, instanceId: instanceId).map(Self.makeReadListDisplayItem)
    }
  }

  func upsertReadList(dto: ReadList, instanceId: String) {
    do {
      try write { db in
        let compositeId = CompositeID.generate(instanceId: instanceId, id: dto.id)
        if var existing = try KomgaReadList.fetchOne(db, key: compositeId) {
          applyReadList(dto: dto, to: &existing)
          try replaceReadListBookMemberships(db: db, readList: existing)
          syncReadListDownloadStatus(db: db, readList: &existing)
          try save(existing, db: db)
        } else {
          var readList = KomgaReadList(
            id: compositeId,
            readListId: dto.id,
            instanceId: instanceId,
            name: dto.name,
            summary: dto.summary,
            ordered: dto.ordered,
            createdDate: dto.createdDate,
            lastModifiedDate: dto.lastModifiedDate,
            filtered: dto.filtered,
            bookIds: dto.bookIds
          )
          try replaceReadListBookMemberships(db: db, readList: readList)
          syncReadListDownloadStatus(db: db, readList: &readList)
          try save(readList, db: db)
        }
      }
    } catch {
      logger.error("Failed to upsert read list: \(error)")
    }
  }

  func deleteReadList(id: String, instanceId: String) {
    _ = try? write { db in
      try deleteReadListBookMemberships(db: db, readListId: id, instanceId: instanceId)
      try KomgaReadList.deleteOne(db, key: CompositeID.generate(instanceId: instanceId, id: id))
    }
  }

  func replaceReadListBookIds(readListId: String, instanceId: String, bookIds: [String]) {
    try? write { db in
      guard var readList = try fetchReadListRecord(db: db, id: readListId, instanceId: instanceId) else {
        return
      }
      readList.bookIds = bookIds
      try replaceReadListBookMemberships(db: db, readList: readList)
      syncReadListDownloadStatus(db: db, readList: &readList)
      try save(readList, db: db)
    }
  }

  func setReadListPinned(readListId: String, instanceId: String, isPinned: Bool) {
    try? write { db in
      guard var readList = try fetchReadListRecord(db: db, id: readListId, instanceId: instanceId) else {
        return
      }
      readList.isPinned = isPinned
      try save(readList, db: db)
    }
  }

  @discardableResult
  func upsertReadLists(_ readLists: [ReadList], instanceId: String) -> [String] {
    var automaticPolicyReadListIds = Set<String>()
    do {
      try write { db in
        let existingReadLists = try fetchReadLists(db: db, instanceId: instanceId)
        let existingById = Dictionary(uniqueKeysWithValues: existingReadLists.map { ($0.readListId, $0) })
        for readList in readLists {
          var record =
            existingById[readList.id]
            ?? KomgaReadList(
              id: CompositeID.generate(instanceId: instanceId, id: readList.id),
              readListId: readList.id,
              instanceId: instanceId,
              name: readList.name,
              summary: readList.summary,
              ordered: readList.ordered,
              createdDate: readList.createdDate,
              lastModifiedDate: readList.lastModifiedDate,
              filtered: readList.filtered,
              bookIds: readList.bookIds
            )
          applyReadList(dto: readList, to: &record)
          try replaceReadListBookMemberships(db: db, readList: record)
          syncReadListDownloadStatus(db: db, readList: &record)
          if record.offlinePolicy != .manual {
            automaticPolicyReadListIds.insert(record.readListId)
          }
          try save(record, db: db)
        }
      }
    } catch {
      logger.error("Failed to upsert read lists: \(error)")
    }
    return automaticPolicyReadListIds.sorted()
  }

  func deleteReadListsNotIn(_ readListIds: Set<String>, instanceId: String) -> Int {
    (try? write { db in
      let existingReadLists = try fetchReadLists(db: db, instanceId: instanceId)
      var deletedCount = 0
      for readList in existingReadLists where !readListIds.contains(readList.readListId) {
        try deleteReadListBookMemberships(db: db, readListId: readList.readListId, instanceId: instanceId)
        try KomgaReadList.deleteOne(db, key: readList.id)
        deletedCount += 1
      }
      return deletedCount
    }) ?? 0
  }
}

extension DatabaseOperator {
  func orderedCollections(
    db: Database,
    instanceId: String,
    searchText: String = "",
    sort: String? = nil
  ) throws -> [KomgaCollection] {
    let collections = try fetchCollections(db: db, instanceId: instanceId).filter { collection in
      searchText.isEmpty || collection.name.localizedStandardContains(searchText)
    }
    return pinnedFirst(sortCollections(collections, sort: sort))
  }

  func orderedReadLists(
    db: Database,
    instanceId: String,
    searchText: String = "",
    sort: String? = nil
  ) throws -> [KomgaReadList] {
    let readLists = try fetchReadLists(db: db, instanceId: instanceId).filter { readList in
      searchText.isEmpty
        || readList.name.localizedStandardContains(searchText)
        || readList.summary.localizedStandardContains(searchText)
    }
    return pinnedFirst(sortReadLists(readLists, sort: sort))
  }

  func applyCollection(dto: SeriesCollection, to existing: inout KomgaCollection) {
    if existing.name != dto.name { existing.name = dto.name }
    if existing.ordered != dto.ordered { existing.ordered = dto.ordered }
    if existing.filtered != dto.filtered { existing.filtered = dto.filtered }
    if existing.lastModifiedDate != dto.lastModifiedDate {
      existing.lastModifiedDate = dto.lastModifiedDate
    }
    if existing.seriesIds != dto.seriesIds { existing.seriesIds = dto.seriesIds }
  }

  func applyReadList(dto: ReadList, to existing: inout KomgaReadList) {
    if existing.name != dto.name { existing.name = dto.name }
    if existing.summary != dto.summary { existing.summary = dto.summary }
    if existing.ordered != dto.ordered { existing.ordered = dto.ordered }
    if existing.filtered != dto.filtered { existing.filtered = dto.filtered }
    if existing.lastModifiedDate != dto.lastModifiedDate {
      existing.lastModifiedDate = dto.lastModifiedDate
    }
    if existing.bookIds != dto.bookIds { existing.bookIds = dto.bookIds }
  }

  func replaceReadListBookMemberships(db: Database, readList: KomgaReadList) throws {
    try deleteReadListBookMemberships(
      db: db,
      readListId: readList.readListId,
      instanceId: readList.instanceId
    )
    for (position, bookId) in readList.bookIds.enumerated() {
      try ReadListBookMembership(
        instanceId: readList.instanceId,
        readListId: readList.readListId,
        bookId: bookId,
        position: position
      ).insert(db)
    }
  }

  func deleteReadListBookMemberships(db: Database, readListId: String, instanceId: String) throws {
    try db.execute(
      sql: """
        DELETE FROM \(ReadListBookMembership.databaseTableName)
        WHERE instance_id = ?
        AND read_list_id = ?
        """,
      arguments: [instanceId, readListId]
    )
  }

  func fetchReadListBookMemberships(
    db: Database,
    instanceId: String,
    readListIds: [String]? = nil,
    bookIds: [String]? = nil
  ) throws -> [ReadListBookMembership] {
    if let readListIds, readListIds.isEmpty { return [] }
    if let bookIds, bookIds.isEmpty { return [] }

    let chunkSize =
      readListIds != nil && bookIds != nil
      ? max(1, Self.recordFetchChunkSize / 2)
      : Self.recordFetchChunkSize
    let readListChunks: [[String]?] =
      if let readListIds {
        Self.chunkedSQLValues(readListIds, chunkSize: chunkSize).map(Optional.some)
      } else {
        [nil]
      }
    let bookChunks: [[String]?] =
      if let bookIds {
        Self.chunkedSQLValues(bookIds, chunkSize: chunkSize).map(Optional.some)
      } else {
        [nil]
      }

    var memberships: [ReadListBookMembership] = []
    for readListChunk in readListChunks {
      for bookChunk in bookChunks {
        var sql = """
          SELECT *
          FROM \(ReadListBookMembership.databaseTableName)
          WHERE instance_id = ?
          """
        var arguments: StatementArguments = [instanceId]
        if let readListChunk {
          Self.appendSQLInFilter(column: "read_list_id", values: readListChunk, sql: &sql, arguments: &arguments)
        }
        if let bookChunk {
          Self.appendSQLInFilter(column: "book_id", values: bookChunk, sql: &sql, arguments: &arguments)
        }
        memberships.append(contentsOf: try ReadListBookMembership.fetchAll(db, sql: sql, arguments: arguments))
      }
    }
    return memberships.sorted {
      if $0.readListId == $1.readListId {
        return $0.position < $1.position
      }
      return $0.readListId < $1.readListId
    }
  }

  func fetchReadListIdsContainingBooks(db: Database, instanceId: String, bookIds: [String]) throws -> [String] {
    guard !bookIds.isEmpty else { return [] }
    var readListIds = Set<String>()
    for bookIds in Self.chunkedSQLValues(bookIds, chunkSize: Self.recordFetchChunkSize) {
      var sql = """
        SELECT DISTINCT read_list_id
        FROM \(ReadListBookMembership.databaseTableName)
        WHERE instance_id = ?
        """
      var arguments: StatementArguments = [instanceId]
      Self.appendSQLInFilter(column: "book_id", values: bookIds, sql: &sql, arguments: &arguments)
      readListIds.formUnion(try String.fetchAll(db, sql: sql, arguments: arguments))
    }
    return readListIds.sorted()
  }

  func fetchReadListsAndMembershipsContainingBooks(
    db: Database,
    instanceId: String,
    bookIds: [String]
  ) throws -> (readLists: [KomgaReadList], memberships: [ReadListBookMembership]) {
    let readListIds = try fetchReadListIdsContainingBooks(db: db, instanceId: instanceId, bookIds: bookIds)
    guard !readListIds.isEmpty else { return ([], []) }
    return (
      try fetchReadListsByIds(db: db, ids: readListIds, instanceId: instanceId),
      try fetchReadListBookMemberships(db: db, instanceId: instanceId, readListIds: readListIds)
    )
  }

  func fetchReadListsByIds(db: Database, ids: [String], instanceId: String) throws -> [KomgaReadList] {
    guard !ids.isEmpty else { return [] }
    var readLists: [KomgaReadList] = []
    for ids in Self.chunkedSQLValues(ids, chunkSize: Self.recordFetchChunkSize) {
      var sql = """
        SELECT *
        FROM \(KomgaReadList.databaseTableName)
        WHERE instance_id = ?
        """
      var arguments: StatementArguments = [instanceId]
      Self.appendSQLInFilter(column: "read_list_id", values: ids, sql: &sql, arguments: &arguments)
      readLists.append(contentsOf: try KomgaReadList.fetchAll(db, sql: sql, arguments: arguments))
    }
    return Self.orderedByIds(readLists, ids: ids, id: \.readListId)
  }

  nonisolated static func chunkedSQLValues(_ values: [String], chunkSize: Int) -> [[String]] {
    let uniqueValues = Array(Set(values))
    guard !uniqueValues.isEmpty else { return [] }
    let safeChunkSize = max(1, chunkSize)
    return stride(from: 0, to: uniqueValues.count, by: safeChunkSize).map { start in
      let end = min(start + safeChunkSize, uniqueValues.count)
      return Array(uniqueValues[start..<end])
    }
  }

  nonisolated static func makeCollectionDisplayItem(_ collection: KomgaCollection) -> CollectionDisplayItem {
    CollectionDisplayItem(
      collectionId: collection.collectionId,
      instanceId: collection.instanceId,
      name: collection.name,
      ordered: collection.ordered,
      createdDate: collection.createdDate,
      lastModifiedDate: collection.lastModifiedDate,
      filtered: collection.filtered,
      isPinned: collection.isPinned,
      seriesIds: collection.seriesIds
    )
  }

  nonisolated static func makeReadListDisplayItem(_ readList: KomgaReadList) -> ReadListDisplayItem {
    ReadListDisplayItem(
      readListId: readList.readListId,
      instanceId: readList.instanceId,
      name: readList.name,
      summary: readList.summary,
      ordered: readList.ordered,
      createdDate: readList.createdDate,
      lastModifiedDate: readList.lastModifiedDate,
      filtered: readList.filtered,
      isPinned: readList.isPinned,
      bookIds: readList.bookIds,
      downloadStatus: readList.downloadStatus,
      offlinePolicy: readList.offlinePolicy,
      offlinePolicyLimit: readList.offlinePolicyLimit
    )
  }

  nonisolated func pinnedFirst(_ collections: [KomgaCollection]) -> [KomgaCollection] {
    collections.filter(\.isPinned) + collections.filter { !$0.isPinned }
  }

  nonisolated func pinnedFirst(_ readLists: [KomgaReadList]) -> [KomgaReadList] {
    readLists.filter(\.isPinned) + readLists.filter { !$0.isPinned }
  }

  nonisolated func sortCollections(_ collections: [KomgaCollection], sort: String?) -> [KomgaCollection] {
    let isAscending = sort?.contains("desc") != true
    if sort?.contains("createdDate") == true {
      return collections.sorted { isAscending ? $0.createdDate < $1.createdDate : $0.createdDate > $1.createdDate }
    }
    if sort?.contains("lastModifiedDate") == true {
      return collections.sorted {
        isAscending ? $0.lastModifiedDate < $1.lastModifiedDate : $0.lastModifiedDate > $1.lastModifiedDate
      }
    }
    return collections.sorted { isAscending ? $0.name < $1.name : $0.name > $1.name }
  }

  nonisolated func sortReadLists(_ readLists: [KomgaReadList], sort: String?) -> [KomgaReadList] {
    let isAscending = sort?.contains("desc") != true
    if sort?.contains("createdDate") == true {
      return readLists.sorted { isAscending ? $0.createdDate < $1.createdDate : $0.createdDate > $1.createdDate }
    }
    if sort?.contains("lastModifiedDate") == true {
      return readLists.sorted {
        isAscending ? $0.lastModifiedDate < $1.lastModifiedDate : $0.lastModifiedDate > $1.lastModifiedDate
      }
    }
    return readLists.sorted { isAscending ? $0.name < $1.name : $0.name > $1.name }
  }

  nonisolated static func collectionOrderSQL(sort: String?) -> String {
    let direction = sort?.contains("desc") == true ? "DESC" : "ASC"
    if sort?.contains("createdDate") == true {
      return "created_date \(direction), id ASC"
    }
    if sort?.contains("lastModifiedDate") == true {
      return "last_modified_date \(direction), id ASC"
    }
    return "name \(direction), id ASC"
  }

  nonisolated static func readListOrderSQL(sort: String?) -> String {
    let direction = sort?.contains("desc") == true ? "DESC" : "ASC"
    if sort?.contains("createdDate") == true {
      return "created_date \(direction), id ASC"
    }
    if sort?.contains("lastModifiedDate") == true {
      return "last_modified_date \(direction), id ASC"
    }
    return "name \(direction), id ASC"
  }
}
