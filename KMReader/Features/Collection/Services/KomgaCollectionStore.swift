//
//  KomgaCollectionStore.swift
//  KMReader
//
//  Created by Komga iOS Client
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
    let instanceId = AppConfig.current.instanceId

    var descriptor = FetchDescriptor<KomgaCollection>()

    if let search = search, !search.isEmpty {
      descriptor.predicate = #Predicate<KomgaCollection> { col in
        col.instanceId == instanceId && col.name.localizedStandardContains(search)
      }
    } else {
      descriptor.predicate = #Predicate<KomgaCollection> { col in
        col.instanceId == instanceId
      }
    }

    if let sort = sort {
      if sort.contains("name") {
        let isAsc = !sort.contains("desc")
        descriptor.sortBy = [
          SortDescriptor(\KomgaCollection.name, order: isAsc ? .forward : .reverse)
        ]
      } else if sort.contains("createdDate") {
        let isAsc = !sort.contains("desc")
        descriptor.sortBy = [
          SortDescriptor(\KomgaCollection.createdDate, order: isAsc ? .forward : .reverse)
        ]
      } else {
        descriptor.sortBy = [SortDescriptor(\KomgaCollection.name, order: .forward)]
      }
    } else {
      descriptor.sortBy = [SortDescriptor(\KomgaCollection.name, order: .forward)]
    }

    descriptor.fetchLimit = size
    descriptor.fetchOffset = page * size

    do {
      let results = try context.fetch(descriptor)
      return results.map { $0.toCollection() }
    } catch {
      return []
    }
  }

  static func fetchCollectionIds(
    context: ModelContext,
    libraryIds: [String]?,
    searchText: String,
    sort: String?,
    offset: Int,
    limit: Int
  ) -> [String] {
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

    if let sort = sort {
      if sort.contains("name") {
        let isAsc = !sort.contains("desc")
        descriptor.sortBy = [
          SortDescriptor(\KomgaCollection.name, order: isAsc ? .forward : .reverse)
        ]
      } else if sort.contains("createdDate") {
        let isAsc = !sort.contains("desc")
        descriptor.sortBy = [
          SortDescriptor(\KomgaCollection.createdDate, order: isAsc ? .forward : .reverse)
        ]
      } else {
        descriptor.sortBy = [SortDescriptor(\KomgaCollection.name, order: .forward)]
      }
    } else {
      descriptor.sortBy = [SortDescriptor(\KomgaCollection.name, order: .forward)]
    }

    descriptor.fetchLimit = limit
    descriptor.fetchOffset = offset

    do {
      let results = try context.fetch(descriptor)
      return results.map { $0.collectionId }
    } catch {
      return []
    }
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
}
