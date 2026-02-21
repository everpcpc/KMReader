//
// KomgaSeriesStore.swift
//
//

import Dependencies
import Foundation
import SQLiteData

/// Provides read-only fetch operations for KomgaSeries data.
enum KomgaSeriesStore {

  nonisolated static func fetchSeries(
    libraryIds: [String]?,
    page: Int,
    size: Int,
    sort: String,
    searchTerm: String?
  ) -> [Series] {
    let instanceId = AppConfig.current.instanceId
    let ids = libraryIds ?? []

    do {
      var records = try fetchSeriesForInstance(instanceId: instanceId, libraryIds: ids.isEmpty ? nil : ids)
      let stateMap = try fetchSeriesStateMap(series: records)

      if let searchTerm, !searchTerm.isEmpty {
        records = records.filter {
          $0.name.localizedStandardContains(searchTerm)
            || $0.metaTitle.localizedStandardContains(searchTerm)
        }
      }

      records = sortedSeries(records, sort: sort, stateMap: stateMap)
      let pageSlice = paginate(records, page: page, size: size)
      return pageSlice.map { $0.toSeries() }
    } catch {
      return []
    }
  }

  nonisolated static func fetchSeriesIds(
    libraryIds: [String]?,
    searchText: String,
    browseOpts: SeriesBrowseOptions,
    offset: Int,
    limit: Int,
    offlineOnly: Bool = false
  ) -> [String] {
    let instanceId = AppConfig.current.instanceId
    let ids = libraryIds ?? []

    do {
      var records = try fetchSeriesForInstance(instanceId: instanceId, libraryIds: ids.isEmpty ? nil : ids)
      let stateMap = try fetchSeriesStateMap(series: records)

      if !searchText.isEmpty {
        records = records.filter {
          $0.name.localizedStandardContains(searchText)
            || $0.metaTitle.localizedStandardContains(searchText)
        }
      }

      if offlineOnly {
        records = records.filter {
          guard let state = stateMap[$0.seriesId] else { return false }
          return state.downloadedBooks > 0 || state.pendingBooks > 0 || state.downloadStatusRaw == "downloaded"
        }
      }

      records = sortedSeries(records, sort: browseOpts.sortString, stateMap: stateMap)
      let slice = paginate(records, offset: offset, limit: limit)
      return slice.map { $0.seriesId }
    } catch {
      return []
    }
  }

  nonisolated static func fetchSeriesByIds(
    ids: [String],
    instanceId: String
  ) -> [KomgaSeriesRecord] {
    guard !ids.isEmpty else { return [] }

    do {
      @Dependency(\.defaultDatabase) var database
      let records = try database.read { db in
        try KomgaSeriesRecord
          .where { $0.instanceId.eq(instanceId) && $0.seriesId.in(ids) }
          .fetchAll(db)
      }

      let idToIndex = Dictionary(uniqueKeysWithValues: ids.enumerated().map { ($0.element, $0.offset) })
      return records.sorted {
        (idToIndex[$0.seriesId] ?? Int.max) < (idToIndex[$1.seriesId] ?? Int.max)
      }
    } catch {
      return []
    }
  }

  nonisolated static func fetchNewlyAddedSeriesIds(
    libraryIds: [String],
    offset: Int,
    limit: Int
  ) -> [String] {
    let instanceId = AppConfig.current.instanceId

    do {
      var records = try fetchSeriesForInstance(
        instanceId: instanceId,
        libraryIds: libraryIds.isEmpty ? nil : libraryIds
      )
      records.sort { $0.created > $1.created }
      let slice = paginate(records, offset: offset, limit: limit)
      return slice.map { $0.seriesId }
    } catch {
      return []
    }
  }

  nonisolated static func fetchRecentlyUpdatedSeriesIds(
    libraryIds: [String],
    offset: Int,
    limit: Int
  ) -> [String] {
    let instanceId = AppConfig.current.instanceId

    do {
      var records = try fetchSeriesForInstance(
        instanceId: instanceId,
        libraryIds: libraryIds.isEmpty ? nil : libraryIds
      )
      records.sort { $0.lastModified > $1.lastModified }
      let slice = paginate(records, offset: offset, limit: limit)
      return slice.map { $0.seriesId }
    } catch {
      return []
    }
  }

  nonisolated static func fetchOne(seriesId: String) -> Series? {
    let instanceId = AppConfig.current.instanceId

    do {
      @Dependency(\.defaultDatabase) var database
      return try database.read { db in
        try KomgaSeriesRecord
          .where { $0.instanceId.eq(instanceId) && $0.seriesId.eq(seriesId) }
          .fetchOne(db)?
          .toSeries()
      }
    } catch {
      return nil
    }
  }

  nonisolated static func fetchCollectionSeries(
    collectionId: String,
    page: Int,
    size: Int,
    browseOpts: CollectionSeriesBrowseOptions
  ) -> [Series] {
    let instanceId = AppConfig.current.instanceId

    do {
      @Dependency(\.defaultDatabase) var database
      guard
        let collection = try database.read({ db in
          try KomgaCollectionRecord
            .where { $0.instanceId.eq(instanceId) && $0.collectionId.eq(collectionId) }
            .fetchOne(db)
        })
      else {
        return []
      }

      let seriesIds = collection.seriesIds
      let allSeries = fetchSeriesByIds(ids: seriesIds, instanceId: instanceId)

      let filtered = allSeries.filter { series in
        if let deletedState = browseOpts.deletedFilter.effectiveBool {
          if series.deleted != deletedState { return false }
        }

        if let oneshotState = browseOpts.oneshotFilter.effectiveBool {
          if series.oneshot != oneshotState { return false }
        }

        if let completeState = browseOpts.completeFilter.effectiveBool {
          if (series.metadata.totalBookCount == series.booksCount) != completeState { return false }
        }

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
    } catch {
      return []
    }
  }

  nonisolated private static func fetchSeriesForInstance(instanceId: String, libraryIds: [String]?) throws
    -> [KomgaSeriesRecord]
  {
    @Dependency(\.defaultDatabase) var database

    return try database.read { db in
      if let libraryIds, !libraryIds.isEmpty {
        return
          try KomgaSeriesRecord
          .where { $0.instanceId.eq(instanceId) && $0.libraryId.in(libraryIds) }
          .fetchAll(db)
      }

      return
        try KomgaSeriesRecord
        .where { $0.instanceId.eq(instanceId) }
        .fetchAll(db)
    }
  }

  nonisolated private static func fetchSeriesStateMap(series: [KomgaSeriesRecord]) throws
    -> [String: KomgaSeriesLocalStateRecord]
  {
    guard !series.isEmpty else { return [:] }
    @Dependency(\.defaultDatabase) var database
    let grouped = Dictionary(grouping: series, by: \.instanceId)
    return try database.read { db in
      var stateMap: [String: KomgaSeriesLocalStateRecord] = [:]
      for (instanceId, groupedSeries) in grouped {
        let seriesIds = Array(Set(groupedSeries.map(\.seriesId)))
        guard !seriesIds.isEmpty else { continue }
        let states =
          try KomgaSeriesLocalStateRecord
          .where { $0.instanceId.eq(instanceId) && $0.seriesId.in(seriesIds) }
          .fetchAll(db)
        for state in states {
          stateMap[state.seriesId] = state
        }
      }
      return stateMap
    }
  }

  nonisolated private static func sortedSeries(
    _ series: [KomgaSeriesRecord],
    sort: String,
    stateMap: [String: KomgaSeriesLocalStateRecord] = [:]
  ) -> [KomgaSeriesRecord] {
    let parts = sort.split(separator: ",")
    let isAsc = parts.count > 1 ? parts[1] == "asc" : true

    if sort.contains("metadata.titleSort") {
      return series.sorted {
        compareString($0.metaTitleSort, $1.metaTitleSort, ascending: isAsc)
      }
    }

    if sort.contains("created") {
      return series.sorted {
        isAsc ? ($0.created < $1.created) : ($0.created > $1.created)
      }
    }

    if sort.contains("lastModified") {
      return series.sorted {
        isAsc ? ($0.lastModified < $1.lastModified) : ($0.lastModified > $1.lastModified)
      }
    }

    if sort.contains("downloadAt") {
      return series.sorted {
        compareOptionalDate(
          stateMap[$0.seriesId]?.downloadAt,
          stateMap[$1.seriesId]?.downloadAt,
          ascending: isAsc
        )
      }
    }

    if sort.contains("booksCount") {
      return series.sorted {
        isAsc ? ($0.booksCount < $1.booksCount) : ($0.booksCount > $1.booksCount)
      }
    }

    return series.sorted {
      compareString($0.metaTitleSort, $1.metaTitleSort, ascending: true)
    }
  }

  nonisolated private static func compareOptionalDate(_ lhs: Date?, _ rhs: Date?, ascending: Bool) -> Bool {
    switch (lhs, rhs) {
    case (let l?, let r?):
      return ascending ? (l < r) : (l > r)
    case (nil, nil):
      return false
    case (nil, _):
      return !ascending
    case (_, nil):
      return ascending
    }
  }

  nonisolated private static func compareString(_ lhs: String, _ rhs: String, ascending: Bool) -> Bool {
    let order = lhs.localizedStandardCompare(rhs)
    return ascending ? order == .orderedAscending : order == .orderedDescending
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
