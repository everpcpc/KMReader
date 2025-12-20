//
//  KomgaSeriesStore.swift
//  KMReader
//
//  Created by Komga iOS Client
//

import Foundation
import SwiftData

@MainActor
final class KomgaSeriesStore {
  static let shared = KomgaSeriesStore()

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

  func fetchSeries(
    libraryIds: [String]?,
    page: Int,
    size: Int,
    sort: String,
    searchTerm: String?
  ) -> [Series] {
    guard let container else { return [] }
    let context = ModelContext(container)

    // Parse Sort
    // Format: "field,direction" (e.g., "metadata.titleSort,asc")
    // SwiftData SortDescriptor requires KeyPath.
    // Handling dynamic sort keypaths is tricky.
    // For now, let's default to titleSort if complex.

    let parts = sort.split(separator: ",")
    let isAsc = parts.count > 1 ? parts[1] == "asc" : true

    // Predicate
    // We can't easily do dynamic predicates for all options yet.
    // Let's handle LibraryID and SearchTerm.

    // SwiftData predicates must be build carefully.
    // If libraryIds is nil/empty, we fetch all?
    // Swift 5.9 Macros make this static.

    let ids = libraryIds ?? []

    var descriptor = FetchDescriptor<KomgaSeries>()

    if !ids.isEmpty {
      if let search = searchTerm, !search.isEmpty {
        descriptor.predicate = #Predicate<KomgaSeries> { series in
          ids.contains(series.libraryId)
            && (series.name.localizedStandardContains(search)
              || series.metaTitle.localizedStandardContains(search))
        }
      } else {
        descriptor.predicate = #Predicate<KomgaSeries> { series in
          ids.contains(series.libraryId)
        }
      }
    } else {
      // All libraries
      if let search = searchTerm, !search.isEmpty {
        descriptor.predicate = #Predicate<KomgaSeries> { series in
          series.name.localizedStandardContains(search)
            || series.metaTitle.localizedStandardContains(search)
        }
      }
    }

    // Sort
    // Basic support for titleSort and dateAdded (created)
    if sort.contains("metadata.titleSort") {
      descriptor.sortBy = [
        SortDescriptor(\KomgaSeries.metaTitleSort, order: isAsc ? .forward : .reverse)
      ]
    } else if sort.contains("created") {
      descriptor.sortBy = [SortDescriptor(\KomgaSeries.created, order: isAsc ? .forward : .reverse)]
    } else if sort.contains("lastModified") {
      descriptor.sortBy = [
        SortDescriptor(\KomgaSeries.lastModified, order: isAsc ? .forward : .reverse)
      ]
    } else if sort.contains("booksCount") {
      descriptor.sortBy = [
        SortDescriptor(\KomgaSeries.booksCount, order: isAsc ? .forward : .reverse)
      ]
    } else {
      descriptor.sortBy = [SortDescriptor(\KomgaSeries.metaTitleSort, order: .forward)]
    }

    descriptor.fetchLimit = size
    descriptor.fetchOffset = page * size

    do {
      let results = try context.fetch(descriptor)
      return results.map { $0.toSeries() }
    } catch {
      return []
    }
  }

  func fetchSeriesIds(
    libraryIds: [String]?,
    searchText: String,
    browseOpts: SeriesBrowseOptions,
    offset: Int,
    limit: Int
  ) -> [String] {
    guard let container else { return [] }
    let context = ModelContext(container)
    let instanceId = AppConfig.currentInstanceId

    let ids = libraryIds ?? []
    var descriptor = FetchDescriptor<KomgaSeries>()

    if !searchText.isEmpty {
      if !ids.isEmpty {
        descriptor.predicate = #Predicate<KomgaSeries> { series in
          series.instanceId == instanceId && ids.contains(series.libraryId)
            && (series.name.localizedStandardContains(searchText)
              || series.metaTitle.localizedStandardContains(searchText))
        }
      } else {
        descriptor.predicate = #Predicate<KomgaSeries> { series in
          series.instanceId == instanceId
            && (series.name.localizedStandardContains(searchText)
              || series.metaTitle.localizedStandardContains(searchText))
        }
      }
    } else {
      if !ids.isEmpty {
        descriptor.predicate = #Predicate<KomgaSeries> { series in
          series.instanceId == instanceId && ids.contains(series.libraryId)
        }
      } else {
        descriptor.predicate = #Predicate<KomgaSeries> { series in
          series.instanceId == instanceId
        }
      }
    }

    // Sort
    let sort = browseOpts.sortString
    let isAsc = !sort.contains("desc")
    if sort.contains("metadata.titleSort") {
      descriptor.sortBy = [
        SortDescriptor(\KomgaSeries.metaTitleSort, order: isAsc ? .forward : .reverse)
      ]
    } else if sort.contains("created") {
      descriptor.sortBy = [SortDescriptor(\KomgaSeries.created, order: isAsc ? .forward : .reverse)]
    } else if sort.contains("lastModified") {
      descriptor.sortBy = [
        SortDescriptor(\KomgaSeries.lastModified, order: isAsc ? .forward : .reverse)
      ]
    } else {
      descriptor.sortBy = [SortDescriptor(\KomgaSeries.metaTitleSort, order: .forward)]
    }

    descriptor.fetchLimit = limit
    descriptor.fetchOffset = offset

    do {
      let results = try context.fetch(descriptor)
      return results.map { $0.seriesId }
    } catch {
      return []
    }
  }

  func fetchRecentSeriesIds(
    libraryIds: [String],
    offset: Int,
    limit: Int
  ) -> [String] {
    guard let container else { return [] }
    let context = ModelContext(container)
    let instanceId = AppConfig.currentInstanceId

    let ids = libraryIds
    var descriptor = FetchDescriptor<KomgaSeries>()

    if !ids.isEmpty {
      descriptor.predicate = #Predicate<KomgaSeries> { series in
        series.instanceId == instanceId && ids.contains(series.libraryId)
      }
    } else {
      descriptor.predicate = #Predicate<KomgaSeries> { series in
        series.instanceId == instanceId
      }
    }

    descriptor.sortBy = [SortDescriptor(\KomgaSeries.lastModified, order: .reverse)]
    descriptor.fetchLimit = limit
    descriptor.fetchOffset = offset

    do {
      let results = try context.fetch(descriptor)
      return results.map { $0.seriesId }
    } catch {
      return []
    }
  }

  func fetchOne(seriesId: String) -> Series? {

    guard let container else { return nil }
    let context = ModelContext(container)
    // We assume current instance for now, or check all?
    // Composite ID is instanceId_seriesId.
    let instanceId = AppConfig.currentInstanceId
    let compositeId = "\(instanceId)_\(seriesId)"

    let descriptor = FetchDescriptor<KomgaSeries>(
      predicate: #Predicate { $0.id == compositeId }
    )

    return try? context.fetch(descriptor).first?.toSeries()
  }

  func fetchCollectionSeries(collectionId: String, page: Int, size: Int) -> [Series] {
    guard let container else { return [] }
    let context = ModelContext(container)
    let instanceId = AppConfig.currentInstanceId
    let collectionCompositeId = "\(instanceId)_\(collectionId)"

    // Find the collection first
    let descriptor = FetchDescriptor<KomgaCollection>(
      predicate: #Predicate { $0.id == collectionCompositeId })
    guard let collection = try? context.fetch(descriptor).first else { return [] }

    // Get series IDs from collection
    let seriesIds = collection.seriesIds

    // Pagination logic manually since we have IDs?
    // Or we can fetch all series matching these IDs.
    // If collection is large, this is inefficient.
    // But SwiftData doesn't support "in array" predicate easily for large arrays.
    // And pagination *within* the array is tricky.

    // Let's assume for now we fetch what we can.
    // Efficient way:
    let start = page * size
    let end = min(start + size, seriesIds.count)

    guard start < seriesIds.count else { return [] }

    let pageIds = Array(seriesIds[start..<end])

    var seriesList: [Series] = []
    for sId in pageIds {
      if let s = fetchOne(seriesId: sId) {
        seriesList.append(s)
      }
    }

    return seriesList
  }
}
