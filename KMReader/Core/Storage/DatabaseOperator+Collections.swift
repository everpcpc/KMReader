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
    return (try? read { db in
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
          var record = existingById[collection.id] ?? KomgaCollection(
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
    return (try? read { db in
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
          try save(existing, db: db)
        } else {
          let readList = KomgaReadList(
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
          try save(readList, db: db)
        }
      }
    } catch {
      logger.error("Failed to upsert read list: \(error)")
    }
  }

  func deleteReadList(id: String, instanceId: String) {
    _ = try? write { db in
      try KomgaReadList.deleteOne(db, key: CompositeID.generate(instanceId: instanceId, id: id))
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

  func upsertReadLists(_ readLists: [ReadList], instanceId: String) {
    do {
      try write { db in
        let existingReadLists = try fetchReadLists(db: db, instanceId: instanceId)
        let existingById = Dictionary(uniqueKeysWithValues: existingReadLists.map { ($0.readListId, $0) })
        for readList in readLists {
          var record = existingById[readList.id] ?? KomgaReadList(
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
          try save(record, db: db)
        }
      }
    } catch {
      logger.error("Failed to upsert read lists: \(error)")
    }
  }

  func deleteReadListsNotIn(_ readListIds: Set<String>, instanceId: String) -> Int {
    (try? write { db in
      let existingReadLists = try fetchReadLists(db: db, instanceId: instanceId)
      var deletedCount = 0
      for readList in existingReadLists where !readListIds.contains(readList.readListId) {
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
      downloadStatus: readList.downloadStatus
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
      return collections.sorted { isAscending ? $0.lastModifiedDate < $1.lastModifiedDate : $0.lastModifiedDate > $1.lastModifiedDate }
    }
    return collections.sorted { isAscending ? $0.name < $1.name : $0.name > $1.name }
  }

  nonisolated func sortReadLists(_ readLists: [KomgaReadList], sort: String?) -> [KomgaReadList] {
    let isAscending = sort?.contains("desc") != true
    if sort?.contains("createdDate") == true {
      return readLists.sorted { isAscending ? $0.createdDate < $1.createdDate : $0.createdDate > $1.createdDate }
    }
    if sort?.contains("lastModifiedDate") == true {
      return readLists.sorted { isAscending ? $0.lastModifiedDate < $1.lastModifiedDate : $0.lastModifiedDate > $1.lastModifiedDate }
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
