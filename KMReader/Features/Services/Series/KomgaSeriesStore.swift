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
    let instanceId = AppConfig.current.instanceId
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
    let instanceId = AppConfig.current.instanceId
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
    let instanceId = AppConfig.current.instanceId
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
    let compositeId = CompositeID.generate(id: seriesId)

    let descriptor = FetchDescriptor<KomgaSeries>(
      predicate: #Predicate { $0.id == compositeId }
    )

    return try? context.fetch(descriptor).first?.toSeries()
  }

  static func fetchCollectionSeries(
    context: ModelContext,
    collectionId: String,
    page: Int,
    size: Int,
    browseOpts: CollectionSeriesBrowseOptions
  ) -> [Series] {
    let instanceId = AppConfig.current.instanceId
    let collectionCompositeId = CompositeID.generate(instanceId: instanceId, id: collectionId)

    let descriptor = FetchDescriptor<KomgaCollection>(
      predicate: #Predicate { $0.id == collectionCompositeId })
    guard let collection = try? context.fetch(descriptor).first else { return [] }

    let seriesIds = collection.seriesIds
    let allSeries = fetchSeriesByIds(context: context, ids: seriesIds, instanceId: instanceId)

    let filtered = allSeries.filter { series in
      // Filter by deleted
      if let deletedState = browseOpts.deletedFilter.effectiveBool {
        if series.isUnavailable != deletedState { return false }
      }

      // Filter by oneshot
      if let oneshotState = browseOpts.oneshotFilter.effectiveBool {
        if series.oneshot != oneshotState { return false }
      }

      // Filter by complete
      if let completeState = browseOpts.completeFilter.effectiveBool {
        if (series.metadata.totalBookCount == series.booksCount) != completeState { return false }
      }

      // Filter by Read Status
      let status: ReadStatus
      if series.booksReadCount == series.booksCount && series.booksCount > 0 {
        status = .read
      } else if series.booksReadCount > 0 {
        status = .inProgress
      } else {
        status = .unread
      }

      if !browseOpts.includeReadStatuses.isEmpty {
        if !browseOpts.includeReadStatuses.contains(status) { return false }
      }

      if !browseOpts.excludeReadStatuses.isEmpty {
        if browseOpts.excludeReadStatuses.contains(status) { return false }
      }

      // Filter by Series Status
      if !browseOpts.includeSeriesStatuses.isEmpty || !browseOpts.excludeSeriesStatuses.isEmpty {
        if let seriesStatus = SeriesStatus.fromAPIValue(series.metadata.status) {
          if !browseOpts.includeSeriesStatuses.isEmpty {
            if !browseOpts.includeSeriesStatuses.contains(seriesStatus) { return false }
          }

          if !browseOpts.excludeSeriesStatuses.isEmpty {
            if browseOpts.excludeSeriesStatuses.contains(seriesStatus) { return false }
          }
        }
      }

      return true
    }

    let start = page * size
    guard start < filtered.count else { return [] }
    let end = min(start + size, filtered.count)
    let pageSlice = filtered[start..<end]

    return pageSlice.map { $0.toSeries() }
  }
}
