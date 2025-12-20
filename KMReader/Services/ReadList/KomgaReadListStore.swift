//
//  KomgaReadListStore.swift
//  KMReader
//
//  Created by Komga iOS Client
//

import Foundation
import SwiftData

@MainActor
final class KomgaReadListStore {
  static let shared = KomgaReadListStore()

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

  func fetchReadLists(
    libraryIds: [String]?,
    page: Int,
    size: Int,
    sort: String?,
    search: String?
  ) -> [ReadList] {
    guard let container else { return [] }
    let context = ModelContext(container)
    let instanceId = AppConfig.currentInstanceId

    // Predicate: Instance ID + Search
    var descriptor = FetchDescriptor<KomgaReadList>()

    if let search = search, !search.isEmpty {
      descriptor.predicate = #Predicate<KomgaReadList> { rl in
        rl.instanceId == instanceId
          && (rl.name.localizedStandardContains(search) || rl.summary.localizedStandardContains(search))
      }
    } else {
      descriptor.predicate = #Predicate<KomgaReadList> { rl in
        rl.instanceId == instanceId
      }
    }

    // Sort
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

  func fetchReadListIds(
    libraryIds: [String]?,
    searchText: String,
    sort: String?,
    offset: Int,
    limit: Int
  ) -> [String] {
    guard let container else { return [] }
    let context = ModelContext(container)
    let instanceId = AppConfig.currentInstanceId

    var descriptor = FetchDescriptor<KomgaReadList>()

    if !searchText.isEmpty {
      descriptor.predicate = #Predicate<KomgaReadList> { rl in
        rl.instanceId == instanceId
          && (rl.name.localizedStandardContains(searchText) || rl.summary.localizedStandardContains(searchText))
      }
    } else {
      descriptor.predicate = #Predicate<KomgaReadList> { rl in
        rl.instanceId == instanceId
      }
    }

    // Sort
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

  func fetchReadList(id: String) -> ReadList? {
    guard let container else { return nil }
    let context = ModelContext(container)
    let compositeId = "\(AppConfig.currentInstanceId)_\(id)"
    let descriptor = FetchDescriptor<KomgaReadList>(predicate: #Predicate { $0.id == compositeId })
    return try? context.fetch(descriptor).first?.toReadList()
  }
}
