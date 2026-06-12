//
// KomgaCollectionStore.swift
//
//

import Foundation
import SwiftData

/// Provides read-only fetch operations for KomgaCollection data.
/// All View-facing fetch methods require a ModelContext from the caller.
enum KomgaCollectionStore {

  static func fetchCollections(
    context: ModelContext,
    libraryIds: [String]?,
    page: Int,
    size: Int,
    sort: String?,
    search: String?
  ) -> [SeriesCollection] {
    let collections = fetchOrderedCollections(
      context: context,
      searchText: search ?? "",
      sort: sort
    )
    return paginate(collections, offset: page * size, limit: size).map { $0.toCollection() }
  }

  nonisolated static func fetchCollectionIds(
    context: ModelContext,
    libraryIds: [String]?,
    searchText: String,
    sort: String?,
    offset: Int,
    limit: Int
  ) -> [String] {
    let collections = fetchOrderedCollections(
      context: context,
      searchText: searchText,
      sort: sort
    )
    return paginate(collections, offset: offset, limit: limit).map { $0.collectionId }
  }

  static func fetchCollectionsByIds(
    context: ModelContext,
    ids: [String],
    instanceId: String
  ) -> [KomgaCollection] {
    guard !ids.isEmpty else { return [] }

    let descriptor = FetchDescriptor<KomgaCollection>(
      predicate: #Predicate<KomgaCollection> { col in
        col.instanceId == instanceId && ids.contains(col.collectionId)
      }
    )

    do {
      let results = try context.fetch(descriptor)
      let idToIndex = Dictionary(
        uniqueKeysWithValues: ids.enumerated().map { ($0.element, $0.offset) })
      return results.sorted {
        (idToIndex[$0.collectionId] ?? Int.max) < (idToIndex[$1.collectionId] ?? Int.max)
      }
    } catch {
      return []
    }
  }

  static func fetchCollection(context: ModelContext, id: String) -> SeriesCollection? {
    let compositeId = CompositeID.generate(id: id)
    let descriptor = FetchDescriptor<KomgaCollection>(
      predicate: #Predicate { $0.id == compositeId })
    return try? context.fetch(descriptor).first?.toCollection()
  }

  nonisolated private static func fetchOrderedCollections(
    context: ModelContext,
    searchText: String,
    sort: String?
  ) -> [KomgaCollection] {
    let instanceId = AppConfig.current.instanceId

    var descriptor = FetchDescriptor<KomgaCollection>()

    if !searchText.isEmpty {
      descriptor.predicate = #Predicate<KomgaCollection> { col in
        col.instanceId == instanceId && col.name.localizedStandardContains(searchText)
      }
    } else {
      descriptor.predicate = #Predicate<KomgaCollection> { col in
        col.instanceId == instanceId
      }
    }

    descriptor.sortBy = sortDescriptors(sort: sort)

    do {
      let results = try context.fetch(descriptor)
      return pinnedFirst(results)
    } catch {
      return []
    }
  }

  nonisolated private static func pinnedFirst(_ collections: [KomgaCollection]) -> [KomgaCollection] {
    let pinned = collections.filter(\.isPinned)
    let unpinned = collections.filter { !$0.isPinned }
    return pinned + unpinned
  }

  nonisolated private static func sortDescriptors(sort: String?) -> [SortDescriptor<KomgaCollection>] {
    let isAscending = sort?.contains("desc") != true

    if sort?.contains("createdDate") == true {
      return [
        SortDescriptor(\KomgaCollection.createdDate, order: isAscending ? .forward : .reverse)
      ]
    }

    if sort?.contains("lastModifiedDate") == true {
      return [
        SortDescriptor(\KomgaCollection.lastModifiedDate, order: isAscending ? .forward : .reverse)
      ]
    }

    return [
      SortDescriptor(\KomgaCollection.name, order: isAscending ? .forward : .reverse)
    ]
  }

  nonisolated private static func paginate(
    _ collections: [KomgaCollection],
    offset: Int,
    limit: Int
  ) -> ArraySlice<KomgaCollection> {
    guard !collections.isEmpty, limit > 0 else { return [] }
    let safeOffset = min(max(0, offset), collections.count)
    let end = min(safeOffset + limit, collections.count)
    return collections[safeOffset..<end]
  }
}
