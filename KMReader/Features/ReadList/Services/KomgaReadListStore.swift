//
// KomgaReadListStore.swift
//
//

import Foundation
import SwiftData

/// Provides read-only fetch operations for KomgaReadList data.
/// All View-facing fetch methods require a ModelContext from the caller.
enum KomgaReadListStore {

  static func fetchReadLists(
    context: ModelContext,
    libraryIds: [String]?,
    page: Int,
    size: Int,
    sort: String?,
    search: String?
  ) -> [ReadList] {
    let instanceId = AppConfig.current.instanceId

    var descriptor = FetchDescriptor<KomgaReadList>()

    if let search = search, !search.isEmpty {
      descriptor.predicate = #Predicate<KomgaReadList> { rl in
        rl.instanceId == instanceId
          && (rl.name.localizedStandardContains(search)
            || rl.summary.localizedStandardContains(search))
      }
    } else {
      descriptor.predicate = #Predicate<KomgaReadList> { rl in
        rl.instanceId == instanceId
      }
    }

    descriptor.sortBy = sortDescriptors(sort: sort)

    do {
      let results = try context.fetch(descriptor)
      let ordered = pinnedFirst(results)
      return paginate(ordered, offset: page * size, limit: size).map { $0.toReadList() }
    } catch {
      return []
    }
  }

  static func fetchReadListIds(
    context: ModelContext,
    libraryIds: [String]?,
    searchText: String,
    sort: String?,
    offset: Int,
    limit: Int
  ) -> [String] {
    let instanceId = AppConfig.current.instanceId

    var descriptor = FetchDescriptor<KomgaReadList>()

    if !searchText.isEmpty {
      descriptor.predicate = #Predicate<KomgaReadList> { rl in
        rl.instanceId == instanceId
          && (rl.name.localizedStandardContains(searchText)
            || rl.summary.localizedStandardContains(searchText))
      }
    } else {
      descriptor.predicate = #Predicate<KomgaReadList> { rl in
        rl.instanceId == instanceId
      }
    }

    descriptor.sortBy = sortDescriptors(sort: sort)

    do {
      let results = try context.fetch(descriptor)
      let ordered = pinnedFirst(results)
      return paginate(ordered, offset: offset, limit: limit).map { $0.readListId }
    } catch {
      return []
    }
  }

  static func fetchReadListsByIds(
    context: ModelContext,
    ids: [String],
    instanceId: String
  ) -> [KomgaReadList] {
    guard !ids.isEmpty else { return [] }

    let descriptor = FetchDescriptor<KomgaReadList>(
      predicate: #Predicate<KomgaReadList> { rl in
        rl.instanceId == instanceId && ids.contains(rl.readListId)
      }
    )

    do {
      let results = try context.fetch(descriptor)
      let idToIndex = Dictionary(
        uniqueKeysWithValues: ids.enumerated().map { ($0.element, $0.offset) })
      return results.sorted {
        (idToIndex[$0.readListId] ?? Int.max) < (idToIndex[$1.readListId] ?? Int.max)
      }
    } catch {
      return []
    }
  }

  static func fetchReadList(context: ModelContext, id: String) -> ReadList? {
    let compositeId = CompositeID.generate(id: id)
    let descriptor = FetchDescriptor<KomgaReadList>(predicate: #Predicate { $0.id == compositeId })
    return try? context.fetch(descriptor).first?.toReadList()
  }

  private static func sortDescriptors(sort: String?) -> [SortDescriptor<KomgaReadList>] {
    let isAscending = sort?.contains("desc") != true

    if sort?.contains("createdDate") == true {
      return [
        SortDescriptor(\KomgaReadList.createdDate, order: isAscending ? .forward : .reverse)
      ]
    }

    if sort?.contains("lastModifiedDate") == true {
      return [
        SortDescriptor(\KomgaReadList.lastModifiedDate, order: isAscending ? .forward : .reverse)
      ]
    }

    return [
      SortDescriptor(\KomgaReadList.name, order: isAscending ? .forward : .reverse)
    ]
  }

  private static func pinnedFirst(_ readLists: [KomgaReadList]) -> [KomgaReadList] {
    let pinned = readLists.filter(\.isPinned)
    let unpinned = readLists.filter { !$0.isPinned }
    return pinned + unpinned
  }

  private static func paginate(
    _ readLists: [KomgaReadList],
    offset: Int,
    limit: Int
  ) -> ArraySlice<KomgaReadList> {
    guard !readLists.isEmpty, limit > 0 else { return [] }
    let safeOffset = min(max(0, offset), readLists.count)
    let end = min(safeOffset + limit, readLists.count)
    return readLists[safeOffset..<end]
  }
}
