//
//  SeriesViewModel.swift
//  Komga
//
//  Created by Komga iOS Client
//

import Foundation
import SwiftData
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
    context: ModelContext,
    browseOpts: SeriesBrowseOptions,
    searchText: String = "",
    libraryIds: [String]? = nil,
    refresh: Bool = false
  ) async {
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
      let ids = KomgaSeriesStore.fetchSeriesIds(
        context: context,
        libraryIds: libraryIds,
        searchText: searchText,
        browseOpts: browseOpts,
        offset: currentPage * pageSize,
        limit: pageSize
      )
      updateState(context: context, ids: ids, moreAvailable: ids.count == pageSize)
    } else {
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
        updateState(context: context, ids: ids, moreAvailable: !page.last)
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

  func markAsRead(seriesId: String, context: ModelContext, browseOpts: SeriesBrowseOptions) async {
    do {
      try await seriesService.markAsRead(seriesId: seriesId)
      _ = try? await SyncService.shared.syncSeriesDetail(seriesId: seriesId)
      await MainActor.run {
        ErrorManager.shared.notify(message: String(localized: "notification.series.markedRead"))
      }
      await loadSeries(
        context: context, browseOpts: browseOpts, searchText: currentSearchText, refresh: true)
    } catch {
      ErrorManager.shared.alert(error: error)
    }
  }

  func markAsUnread(seriesId: String, context: ModelContext, browseOpts: SeriesBrowseOptions) async
  {
    do {
      try await seriesService.markAsUnread(seriesId: seriesId)
      _ = try? await SyncService.shared.syncSeriesDetail(seriesId: seriesId)
      await MainActor.run {
        ErrorManager.shared.notify(message: String(localized: "notification.series.markedUnread"))
      }
      await loadSeries(
        context: context, browseOpts: browseOpts, searchText: currentSearchText, refresh: true)
    } catch {
      ErrorManager.shared.alert(error: error)
    }
  }

  func loadCollectionSeries(
    context: ModelContext,
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

    if AppConfig.isOffline {
      let series = KomgaSeriesStore.fetchCollectionSeries(
        context: context,
        collectionId: collectionId,
        page: currentPage,
        size: 20,
        browseOpts: browseOpts
      )
      let ids = series.map { $0.id }
      updateState(context: context, ids: ids, moreAvailable: ids.count == 20)
    } else {
      do {
        let page = try await SyncService.shared.syncCollectionSeries(
          collectionId: collectionId,
          page: currentPage,
          size: 20,
          browseOpts: browseOpts,
          libraryIds: libraryIds
        )

        let ids = page.content.map { $0.id }
        updateState(context: context, ids: ids, moreAvailable: !page.last)
      } catch {
        ErrorManager.shared.alert(error: error)
      }
    }

    withAnimation {
      isLoading = false
    }
  }

  private func updateState(context: ModelContext, ids: [String], moreAvailable: Bool) {
    let series = KomgaSeriesStore.fetchSeriesByIds(
      context: context,
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
