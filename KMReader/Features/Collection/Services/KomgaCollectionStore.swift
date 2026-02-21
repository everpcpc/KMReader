//
// KomgaCollectionStore.swift
//
//

import Dependencies
import Foundation
import SQLiteData

/// Provides read-only fetch operations for KomgaCollection data.
enum KomgaCollectionStore {

  nonisolated static func fetchCollections(
    libraryIds _: [String]?,
    page: Int,
    size: Int,
    sort: String?,
    search: String?
  ) -> [SeriesCollection] {
    let instanceId = AppConfig.current.instanceId

    do {
      var records = try fetchCollectionsForInstance(instanceId: instanceId)

      if let search, !search.isEmpty {
        records = records.filter { $0.name.localizedStandardContains(search) }
      }

      records = sortedCollections(records, sort: sort)
      let pageSlice = paginate(records, page: page, size: size)
      return pageSlice.map { $0.toCollection() }
    } catch {
      return []
    }
  }

  nonisolated static func fetchCollectionIds(
    libraryIds _: [String]?,
    searchText: String,
    sort: String?,
    offset: Int,
    limit: Int
  ) -> [String] {
    let instanceId = AppConfig.current.instanceId

    do {
      var records = try fetchCollectionsForInstance(instanceId: instanceId)

      if !searchText.isEmpty {
        records = records.filter { $0.name.localizedStandardContains(searchText) }
      }

      records = sortedCollections(records, sort: sort)
      let slice = paginate(records, offset: offset, limit: limit)
      return slice.map { $0.collectionId }
    } catch {
      return []
    }
  }

  nonisolated static func fetchCollectionsByIds(
    ids: [String],
    instanceId: String
  ) -> [KomgaCollectionRecord] {
    guard !ids.isEmpty else { return [] }

    do {
      @Dependency(\.defaultDatabase) var database
      let records = try database.read { db in
        try KomgaCollectionRecord
          .where { $0.instanceId.eq(instanceId) && $0.collectionId.in(ids) }
          .fetchAll(db)
      }

      let idToIndex = Dictionary(uniqueKeysWithValues: ids.enumerated().map { ($0.element, $0.offset) })
      return records.sorted {
        (idToIndex[$0.collectionId] ?? Int.max) < (idToIndex[$1.collectionId] ?? Int.max)
      }
    } catch {
      return []
    }
  }

  nonisolated static func fetchCollection(id: String) -> SeriesCollection? {
    let instanceId = AppConfig.current.instanceId

    do {
      @Dependency(\.defaultDatabase) var database
      return try database.read { db in
        try KomgaCollectionRecord
          .where { $0.instanceId.eq(instanceId) && $0.collectionId.eq(id) }
          .fetchOne(db)?
          .toCollection()
      }
    } catch {
      return nil
    }
  }

  nonisolated private static func fetchCollectionsForInstance(instanceId: String) throws -> [KomgaCollectionRecord] {
    @Dependency(\.defaultDatabase) var database
    return try database.read { db in
      try KomgaCollectionRecord
        .where { $0.instanceId.eq(instanceId) }
        .fetchAll(db)
    }
  }

  nonisolated private static func sortedCollections(_ collections: [KomgaCollectionRecord], sort: String?)
    -> [KomgaCollectionRecord]
  {
    guard let sort else {
      return collections.sorted {
        $0.name.localizedStandardCompare($1.name) == .orderedAscending
      }
    }

    if sort.contains("name") {
      let isAsc = !sort.contains("desc")
      return collections.sorted {
        let order = $0.name.localizedStandardCompare($1.name)
        return isAsc ? order == .orderedAscending : order == .orderedDescending
      }
    }

    if sort.contains("createdDate") {
      let isAsc = !sort.contains("desc")
      return collections.sorted {
        isAsc ? ($0.createdDate < $1.createdDate) : ($0.createdDate > $1.createdDate)
      }
    }

    return collections.sorted {
      $0.name.localizedStandardCompare($1.name) == .orderedAscending
    }
  }

  nonisolated private static func paginate<T>(_ values: [T], page: Int, size: Int) -> ArraySlice<T> {
    let offset = page * size
    return paginate(values, offset: offset, limit: size)
  }

  nonisolated private static func paginate<T>(_ values: [T], offset: Int, limit: Int) -> ArraySlice<T> {
    guard offset < values.count else { return [] }
    let end = min(offset + limit, values.count)
    return values[offset..<end]
  }
}
