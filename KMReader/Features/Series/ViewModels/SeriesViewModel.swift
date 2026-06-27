//
// SeriesViewModel.swift
//
//

import Foundation
import SwiftUI

@MainActor
@Observable
class SeriesViewModel {
  var isLoading = false

  private(set) var pagination = PaginationState<IdentifiedString>(pageSize: 50)

  func loadSeries(
    browseOpts: SeriesBrowseOptions,
    searchText: String = "",
    libraryIds: [String]? = nil,
    refresh: Bool = false,
    useLocalOnly: Bool = false,
    offlineOnly: Bool = false
  ) async {
    guard let loadID = beginLoad(refresh: refresh) else { return }

    defer {
      if loadID == pagination.loadID {
        withAnimation {
          isLoading = false
        }
      }
    }

    if AppConfig.isOffline || useLocalOnly {
      guard let database = try? await DatabaseOperator.database() else {
        guard loadID == pagination.loadID else { return }
        applyPage(ids: [], moreAvailable: false)
        return
      }
      let ids = await database.fetchBrowseSeriesIds(
        instanceId: AppConfig.current.instanceId,
        libraryIds: libraryIds,
        searchText: searchText,
        browseOpts: browseOpts,
        offset: pagination.currentPage * pagination.pageSize,
        limit: pagination.pageSize,
        offlineOnly: offlineOnly
      )
      guard loadID == pagination.loadID else { return }
      applyPage(ids: ids, moreAvailable: ids.count == pagination.pageSize)
    } else {
      do {
        let page = try await SyncService.syncSeriesPage(
          libraryIds: libraryIds,
          page: pagination.currentPage,
          size: pagination.pageSize,
          searchTerm: searchText.isEmpty ? nil : searchText,
          browseOpts: normalizedRemoteBrowseOptions(browseOpts)
        )

        guard loadID == pagination.loadID else { return }
        let ids = page.content.map { $0.id }
        applyPage(ids: ids, moreAvailable: !page.last)
      } catch {
        guard loadID == pagination.loadID else { return }
        if refresh {
          ErrorManager.shared.alert(error: error)
        }
      }
    }
  }

  func removeSeriesNotMatchingReadStatusFilter(
    seriesIds: Set<String>,
    browseOpts: SeriesBrowseOptions
  ) async {
    guard hasReadStatusFilter(browseOpts) else { return }

    let visibleIds = Set(pagination.items.map(\.id))
    let targetIds = visibleIds.intersection(seriesIds)
    guard !targetIds.isEmpty else { return }
    guard let database = try? await DatabaseOperator.database() else { return }

    var removedIds = Set<String>()
    for seriesId in targetIds {
      guard
        let item = try? await database.fetchSeriesDisplayItem(
          seriesId: seriesId,
          instanceId: AppConfig.current.instanceId
        )
      else {
        removedIds.insert(seriesId)
        continue
      }

      if !matchesReadStatusFilter(
        readStatus(for: item),
        include: browseOpts.includeReadStatuses,
        exclude: browseOpts.excludeReadStatuses
      ) {
        removedIds.insert(seriesId)
      }
    }

    guard !removedIds.isEmpty else { return }
    withAnimation {
      _ = pagination.removeAll { removedIds.contains($0.id) }
    }
  }

  private func normalizedRemoteBrowseOptions(_ browseOpts: SeriesBrowseOptions)
    -> SeriesBrowseOptions
  {
    guard browseOpts.sortField == .downloadDate else {
      return browseOpts
    }

    var fallback = browseOpts
    fallback.sortField = .dateAdded
    return fallback
  }

  private func hasReadStatusFilter(_ browseOpts: SeriesBrowseOptions) -> Bool {
    !browseOpts.includeReadStatuses.isEmpty || !browseOpts.excludeReadStatuses.isEmpty
  }

  private func readStatus(for item: SeriesDisplayItem) -> ReadStatus {
    ReadStatus.fromSeriesCounts(
      booksCount: item.booksCount,
      booksReadCount: item.booksReadCount,
      booksInProgressCount: item.booksInProgressCount
    )
  }

  func loadCollectionSeries(
    collectionId: String,
    browseOpts: CollectionSeriesBrowseOptions,
    libraryIds: [String]? = nil,
    refresh: Bool = false
  ) async {
    guard let loadID = beginLoad(refresh: refresh) else { return }

    defer {
      if loadID == pagination.loadID {
        withAnimation {
          isLoading = false
        }
      }
    }

    if AppConfig.isOffline {
      guard let database = try? await DatabaseOperator.database() else {
        guard loadID == pagination.loadID else { return }
        applyPage(ids: [], moreAvailable: false)
        return
      }
      let ids = await database.fetchCollectionSeriesIds(
        collectionId: collectionId,
        browseOpts: browseOpts,
        page: pagination.currentPage,
        size: pagination.pageSize
      )
      guard loadID == pagination.loadID else { return }
      applyPage(ids: ids, moreAvailable: ids.count == pagination.pageSize)
    } else {
      do {
        let page = try await SyncService.syncCollectionSeries(
          collectionId: collectionId,
          page: pagination.currentPage,
          size: pagination.pageSize,
          browseOpts: browseOpts,
          libraryIds: libraryIds
        )

        guard loadID == pagination.loadID else { return }
        let ids = page.content.map { $0.id }
        applyPage(ids: ids, moreAvailable: !page.last)
      } catch {
        guard loadID == pagination.loadID else { return }
        ErrorManager.shared.alert(error: error)
      }
    }
  }

  private func applyPage(ids: [String], moreAvailable: Bool) {
    let wrappedIds = ids.map(IdentifiedString.init)
    withAnimation {
      _ = pagination.applyPage(wrappedIds)
    }
    pagination.advance(moreAvailable: moreAvailable)
  }

  private func beginLoad(refresh: Bool) -> UUID? {
    if refresh {
      withAnimation {
        pagination.reset()
        isLoading = true
      }
      return pagination.loadID
    }

    guard pagination.hasMorePages && !isLoading else { return nil }
    withAnimation {
      isLoading = true
    }
    return pagination.loadID
  }
}
