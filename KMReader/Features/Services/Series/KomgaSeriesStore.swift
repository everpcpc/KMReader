//
//  KomgaSeriesStore.swift
//  KMReader
//
//  Created by Komga iOS Client
//

import Foundation
import SwiftData

/// Provides read-only fetch operations for KomgaSeries data.
/// All View-facing fetch methods require a ModelContext from the caller.
enum KomgaSeriesStore {

  static func fetchSeries(
    context: ModelContext,
    libraryIds: [String]?,
    page: Int,
    size: Int,
    sort: String,
    searchTerm: String?
  ) -> [Series] {
    let parts = sort.split(separator: ",")
    let isAsc = parts.count > 1 ? parts[1] == "asc" : true
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
      if let search = searchTerm, !search.isEmpty {
        descriptor.predicate = #Predicate<KomgaSeries> { series in
          series.name.localizedStandardContains(search)
            || series.metaTitle.localizedStandardContains(search)
        }
      }
    }

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

  static func fetchSeriesIds(
    context: ModelContext,
    libraryIds: [String]?,
    searchText: String,
    browseOpts: SeriesBrowseOptions,
    offset: Int,
    limit: Int
  ) -> [String] {
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

  static func fetchSeriesByIds(
    context: ModelContext,
    ids: [String],
    instanceId: String
  ) -> [KomgaSeries] {
    guard !ids.isEmpty else { return [] }

    let descriptor = FetchDescriptor<KomgaSeries>(
      predicate: #Predicate<KomgaSeries> { series in
        series.instanceId == instanceId && ids.contains(series.seriesId)
      }
    )

    do {
      let results = try context.fetch(descriptor)
      let idToIndex = Dictionary(
        uniqueKeysWithValues: ids.enumerated().map { ($0.element, $0.offset) })
      return results.sorted {
        (idToIndex[$0.seriesId] ?? Int.max) < (idToIndex[$1.seriesId] ?? Int.max)
      }
    } catch {
      return []
    }
  }

  static func fetchNewlyAddedSeriesIds(
    context: ModelContext,
    libraryIds: [String],
    offset: Int,
    limit: Int
  ) -> [String] {
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

    descriptor.sortBy = [SortDescriptor(\KomgaSeries.created, order: .reverse)]
    descriptor.fetchLimit = limit
    descriptor.fetchOffset = offset

    do {
      let results = try context.fetch(descriptor)
      return results.map { $0.seriesId }
    } catch {
      return []
    }
  }

  static func fetchRecentlyUpdatedSeriesIds(
    context: ModelContext,
    libraryIds: [String],
    offset: Int,
    limit: Int
  ) -> [String] {
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

  static func fetchOne(context: ModelContext, seriesId: String) -> Series? {
    let instanceId = AppConfig.currentInstanceId
    let compositeId = "\(instanceId)_\(seriesId)"

    let descriptor = FetchDescriptor<KomgaSeries>(
      predicate: #Predicate { $0.id == compositeId }
    )

    return try? context.fetch(descriptor).first?.toSeries()
  }

  static func fetchCollectionSeries(
    context: ModelContext,
    collectionId: String,
    page: Int,
    size: Int
  ) -> [Series] {
    let instanceId = AppConfig.currentInstanceId
    let collectionCompositeId = "\(instanceId)_\(collectionId)"

    let descriptor = FetchDescriptor<KomgaCollection>(
      predicate: #Predicate { $0.id == collectionCompositeId })
    guard let collection = try? context.fetch(descriptor).first else { return [] }

    let seriesIds = collection.seriesIds
    let start = page * size
    let end = min(start + size, seriesIds.count)

    guard start < seriesIds.count else { return [] }

    let pageIds = Array(seriesIds[start..<end])

    var seriesList: [Series] = []
    for sId in pageIds {
      if let s = fetchOne(context: context, seriesId: sId) {
        seriesList.append(s)
      }
    }

    return seriesList
  }
}
