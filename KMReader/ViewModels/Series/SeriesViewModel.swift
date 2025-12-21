//
//  SeriesViewModel.swift
//  Komga
//
//  Created by Komga iOS Client
//

import Foundation
import SwiftUI

@MainActor
@Observable
class SeriesViewModel {
  var isLoading = false
  var browseSeriesIds: [String] = []
  var browseSeries: [KomgaSeries] = []

  private let seriesService = SeriesService.shared
  private(set) var currentPage = 0
  private var hasMorePages = true
  private var currentState: SeriesBrowseOptions?
  private var currentSearchText: String = ""

  private let pageSize = 20

  func loadSeries(
    browseOpts: SeriesBrowseOptions, searchText: String = "", libraryIds: [String]? = nil,
    refresh: Bool = false
  )
    async
  {
    let paramsChanged = currentState != browseOpts || currentSearchText != searchText
    let shouldReset = refresh || paramsChanged

    if shouldReset {
      currentPage = 0
      hasMorePages = true
      currentState = browseOpts
      currentSearchText = searchText
    }

    guard hasMorePages && !isLoading else { return }
    isLoading = true

    if AppConfig.isOffline {
      // Offline: query SwiftData directly
      let ids = KomgaSeriesStore.shared.fetchSeriesIds(
        libraryIds: libraryIds,
        searchText: searchText,
        browseOpts: browseOpts,
        offset: currentPage * pageSize,
        limit: pageSize
      )
      updateState(ids: ids, moreAvailable: ids.count == pageSize)
    } else {
      // Online: fetch from API and sync
      do {
        let page = try await SyncService.shared.syncSeriesPage(
          libraryIds: libraryIds,
          page: currentPage,
          size: pageSize,
          sort: browseOpts.sortString,
          searchTerm: searchText.isEmpty ? nil : searchText,
          browseOpts: browseOpts
        )

        let ids = page.content.map { $0.id }
        updateState(ids: ids, moreAvailable: !page.last)
      } catch {
        if shouldReset {
          ErrorManager.shared.alert(error: error)
        }
      }
    }

    withAnimation {
      isLoading = false
    }
  }

  func loadNewSeries(libraryIds: [String]? = nil) async {
    isLoading = true

    do {
      _ = try await SyncService.shared.syncNewSeries(
        libraryIds: libraryIds, page: currentPage, size: 20)
    } catch {
      ErrorManager.shared.alert(error: error)
    }

    withAnimation {
      isLoading = false
    }
  }

  func loadUpdatedSeries(libraryIds: [String]? = nil) async {
    isLoading = true

    do {
      _ = try await SyncService.shared.syncUpdatedSeries(
        libraryIds: libraryIds, page: currentPage, size: 20)
    } catch {
      ErrorManager.shared.alert(error: error)
    }

    withAnimation {
      isLoading = false
    }
  }

  func markAsRead(seriesId: String, browseOpts: SeriesBrowseOptions) async {
    do {
      try await seriesService.markAsRead(seriesId: seriesId)
      _ = try? await SyncService.shared.syncSeriesDetail(seriesId: seriesId)
      await MainActor.run {
        ErrorManager.shared.notify(message: String(localized: "notification.series.markedRead"))
      }
      await loadSeries(browseOpts: browseOpts, searchText: currentSearchText, refresh: true)
    } catch {
      ErrorManager.shared.alert(error: error)
    }
  }

  func markAsUnread(seriesId: String, browseOpts: SeriesBrowseOptions) async {
    do {
      try await seriesService.markAsUnread(seriesId: seriesId)
      _ = try? await SyncService.shared.syncSeriesDetail(seriesId: seriesId)
      await MainActor.run {
        ErrorManager.shared.notify(message: String(localized: "notification.series.markedUnread"))
      }
      await loadSeries(browseOpts: browseOpts, searchText: currentSearchText, refresh: true)
    } catch {
      ErrorManager.shared.alert(error: error)
    }
  }

  func loadCollectionSeries(
    collectionId: String,
    browseOpts: CollectionSeriesBrowseOptions,
    libraryIds: [String]? = nil,
    refresh: Bool = false
  ) async {
    if refresh {
      currentPage = 0
      hasMorePages = true
    }

    guard hasMorePages && !isLoading else { return }

    isLoading = true

    do {
      let page = try await SyncService.shared.syncCollectionSeries(
        collectionId: collectionId,
        page: currentPage,
        size: 20,
        browseOpts: browseOpts,
        libraryIds: libraryIds
      )

      let ids = page.content.map { $0.id }
      updateState(ids: ids, moreAvailable: !page.last)
    } catch {
      ErrorManager.shared.alert(error: error)
    }

    withAnimation {
      isLoading = false
    }
  }

  private func updateState(ids: [String], moreAvailable: Bool) {
    let series = KomgaSeriesStore.shared.fetchSeriesByIds(
      ids: ids, instanceId: AppConfig.currentInstanceId)
    withAnimation {
      if currentPage == 0 {
        browseSeriesIds = ids
        browseSeries = series
      } else {
        browseSeriesIds.append(contentsOf: ids)
        browseSeries.append(contentsOf: series)
      }
    }
    hasMorePages = moreAvailable
    currentPage += 1
  }
}
