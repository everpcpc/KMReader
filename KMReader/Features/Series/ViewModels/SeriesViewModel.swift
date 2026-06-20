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
