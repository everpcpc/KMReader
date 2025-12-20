//
//  KomgaCollectionStore.swift
//  KMReader
//
//  Created by Komga iOS Client
//

import Foundation
import SwiftData

@MainActor
final class KomgaCollectionStore {
  static let shared = KomgaCollectionStore()

  private var container: ModelContainer?

  private init() {}

  func configure(with container: ModelContainer) {
    self.container = container
  }

  private func makeContext() throws -> ModelContext {
    guard let container else {
      throw AppErrorType.storageNotConfigured(message: "ModelContainer is not configured")
    }
    return ModelContext(container)
  }

  func fetchCollections(
    libraryIds: [String]?,
    page: Int,
    size: Int,
    sort: String?,
    search: String?
  ) -> [SeriesCollection] {
    guard let container else { return [] }
    let context = ModelContext(container)
    let instanceId = AppConfig.currentInstanceId

    // Predicate: Instance ID
    var descriptor = FetchDescriptor<KomgaCollection>()

    // NOTE: Collections are global to instance, but "LibraryIds" filter in API
    // usually filters collections that contain series from those libraries.
    // Locally, this is hard without complex joins.
    // For now, if libraryIds are provided, we might ignore locally or try to filter?
    // Let's assume global fetch for now or simple name search.

    if let search = search, !search.isEmpty {
      descriptor.predicate = #Predicate<KomgaCollection> { col in
        col.instanceId == instanceId && col.name.localizedStandardContains(search)
      }
    } else {
      descriptor.predicate = #Predicate<KomgaCollection> { col in
        col.instanceId == instanceId
      }
    }

    // Sort
    // Default name asc
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

  func fetchCollectionIds(
    libraryIds: [String]?,
    searchText: String,
    sort: String?,
    offset: Int,
    limit: Int
  ) -> [String] {
    guard let container else { return [] }
    let context = ModelContext(container)
    let instanceId = AppConfig.currentInstanceId

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

    // Sort
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

  func fetchCollectionsByIds(ids: [String], instanceId: String) -> [KomgaCollection] {
    guard let container, !ids.isEmpty else { return [] }
    let context = ModelContext(container)

    let descriptor = FetchDescriptor<KomgaCollection>(
      predicate: #Predicate<KomgaCollection> { col in
        col.instanceId == instanceId && ids.contains(col.collectionId)
      }
    )

    do {
      let results = try context.fetch(descriptor)
      let idToIndex = Dictionary(uniqueKeysWithValues: ids.enumerated().map { ($0.element, $0.offset) })
      return results.sorted {
        (idToIndex[$0.collectionId] ?? Int.max) < (idToIndex[$1.collectionId] ?? Int.max)
      }
    } catch {
      return []
    }
  }

  func fetchCollection(id: String) -> SeriesCollection? {
    guard let container else { return nil }
    let context = ModelContext(container)
    let compositeId = "\(AppConfig.currentInstanceId)_\(id)"
    let descriptor = FetchDescriptor<KomgaCollection>(
      predicate: #Predicate { $0.id == compositeId })
    return try? context.fetch(descriptor).first?.toCollection()
  }
}
