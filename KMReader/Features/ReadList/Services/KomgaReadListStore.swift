//
//  KomgaReadListStore.swift
//  KMReader
//
//  Created by Komga iOS Client
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

    if let sort = sort {
      if sort.contains("name") {
        let isAsc = !sort.contains("desc")
        descriptor.sortBy = [
          SortDescriptor(\KomgaReadList.name, order: isAsc ? .forward : .reverse)
        ]
      } else if sort.contains("createdDate") {
        let isAsc = !sort.contains("desc")
        descriptor.sortBy = [
          SortDescriptor(\KomgaReadList.createdDate, order: isAsc ? .forward : .reverse)
        ]
      } else {
        descriptor.sortBy = [SortDescriptor(\KomgaReadList.name, order: .forward)]
      }
    } else {
      descriptor.sortBy = [SortDescriptor(\KomgaReadList.name, order: .forward)]
    }

    descriptor.fetchLimit = size
    descriptor.fetchOffset = page * size

    do {
      let results = try context.fetch(descriptor)
      return results.map { $0.toReadList() }
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

    if let sort = sort {
      if sort.contains("name") {
        let isAsc = !sort.contains("desc")
        descriptor.sortBy = [
          SortDescriptor(\KomgaReadList.name, order: isAsc ? .forward : .reverse)
        ]
      } else if sort.contains("createdDate") {
        let isAsc = !sort.contains("desc")
        descriptor.sortBy = [
          SortDescriptor(\KomgaReadList.createdDate, order: isAsc ? .forward : .reverse)
        ]
      } else {
        descriptor.sortBy = [SortDescriptor(\KomgaReadList.name, order: .forward)]
      }
    } else {
      descriptor.sortBy = [SortDescriptor(\KomgaReadList.name, order: .forward)]
    }

    descriptor.fetchLimit = limit
    descriptor.fetchOffset = offset

    do {
      let results = try context.fetch(descriptor)
      return results.map { $0.readListId }
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
}
