//
// KomgaReadListStore.swift
//
//

import Dependencies
import Foundation
import SQLiteData

/// Provides read-only fetch operations for KomgaReadList data.
enum KomgaReadListStore {

  nonisolated static func fetchReadLists(
    libraryIds _: [String]?,
    page: Int,
    size: Int,
    sort: String?,
    search: String?
  ) -> [ReadList] {
    let instanceId = AppConfig.current.instanceId

    do {
      var records = try fetchReadListsForInstance(instanceId: instanceId)

      if let search, !search.isEmpty {
        records = records.filter {
          $0.name.localizedStandardContains(search) || $0.summary.localizedStandardContains(search)
        }
      }

      records = sortedReadLists(records, sort: sort)
      let pageSlice = paginate(records, page: page, size: size)
      return pageSlice.map { $0.toReadList() }
    } catch {
      return []
    }
  }

  nonisolated static func fetchReadListIds(
    libraryIds _: [String]?,
    searchText: String,
    sort: String?,
    offset: Int,
    limit: Int
  ) -> [String] {
    let instanceId = AppConfig.current.instanceId

    do {
      var records = try fetchReadListsForInstance(instanceId: instanceId)

      if !searchText.isEmpty {
        records = records.filter {
          $0.name.localizedStandardContains(searchText) || $0.summary.localizedStandardContains(searchText)
        }
      }

      records = sortedReadLists(records, sort: sort)
      let slice = paginate(records, offset: offset, limit: limit)
      return slice.map { $0.readListId }
    } catch {
      return []
    }
  }

  nonisolated static func fetchReadListsByIds(
    ids: [String],
    instanceId: String
  ) -> [KomgaReadListRecord] {
    guard !ids.isEmpty else { return [] }

    do {
      @Dependency(\.defaultDatabase) var database
      let records = try database.read { db in
        try KomgaReadListRecord
          .where { $0.instanceId.eq(instanceId) && $0.readListId.in(ids) }
          .fetchAll(db)
      }

      let idToIndex = Dictionary(uniqueKeysWithValues: ids.enumerated().map { ($0.element, $0.offset) })
      return records.sorted {
        (idToIndex[$0.readListId] ?? Int.max) < (idToIndex[$1.readListId] ?? Int.max)
      }
    } catch {
      return []
    }
  }

  nonisolated static func fetchReadList(id: String) -> ReadList? {
    let instanceId = AppConfig.current.instanceId

    do {
      @Dependency(\.defaultDatabase) var database
      return try database.read { db in
        try KomgaReadListRecord
          .where { $0.instanceId.eq(instanceId) && $0.readListId.eq(id) }
          .fetchOne(db)?
          .toReadList()
      }
    } catch {
      return nil
    }
  }

  nonisolated private static func fetchReadListsForInstance(instanceId: String) throws -> [KomgaReadListRecord] {
    @Dependency(\.defaultDatabase) var database
    return try database.read { db in
      try KomgaReadListRecord
        .where { $0.instanceId.eq(instanceId) }
        .fetchAll(db)
    }
  }

  nonisolated private static func sortedReadLists(_ readLists: [KomgaReadListRecord], sort: String?)
    -> [KomgaReadListRecord]
  {
    guard let sort else {
      return readLists.sorted {
        $0.name.localizedStandardCompare($1.name) == .orderedAscending
      }
    }

    if sort.contains("name") {
      let isAsc = !sort.contains("desc")
      return readLists.sorted {
        let order = $0.name.localizedStandardCompare($1.name)
        return isAsc ? order == .orderedAscending : order == .orderedDescending
      }
    }

    if sort.contains("createdDate") {
      let isAsc = !sort.contains("desc")
      return readLists.sorted {
        isAsc ? ($0.createdDate < $1.createdDate) : ($0.createdDate > $1.createdDate)
      }
    }

    return readLists.sorted {
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
