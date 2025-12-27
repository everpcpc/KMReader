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

  private let seriesService = SeriesService.shared
  private(set) var currentPage = 0
  private var hasMorePages = true
  private var currentState: SeriesBrowseOptions?
  private var currentSearchText: String = ""

  private let pageSize = 50
  private var currentLoadID = UUID()

  func loadSeries(
    context: ModelContext,
    browseOpts: SeriesBrowseOptions,
    searchText: String = "",
    libraryIds: [String]? = nil,
    refresh: Bool = false
  ) async {
    let paramsChanged = currentState != browseOpts || currentSearchText != searchText
    let shouldReset = refresh || paramsChanged

    if !shouldReset {
      guard hasMorePages && !isLoading else { return }
    }

    if shouldReset {
      currentLoadID = UUID()
      currentPage = 0
      hasMorePages = true
      currentState = browseOpts
      currentSearchText = searchText
    }

    let loadID = currentLoadID
    isLoading = true

    defer {
      if loadID == currentLoadID {
        withAnimation {
          isLoading = false
        }
      }
    }

    if AppConfig.isOffline {
      let ids = KomgaSeriesStore.fetchSeriesIds(
        context: context,
        libraryIds: libraryIds,
        searchText: searchText,
        browseOpts: browseOpts,
        offset: currentPage * pageSize,
        limit: pageSize
      )
      guard loadID == currentLoadID else { return }
      updateState(ids: ids, moreAvailable: ids.count == pageSize)
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

        guard loadID == currentLoadID else { return }
        let ids = page.content.map { $0.id }
        updateState(ids: ids, moreAvailable: !page.last)
      } catch {
        guard loadID == currentLoadID else { return }
        if shouldReset {
          ErrorManager.shared.alert(error: error)
        }
      }
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
    if !refresh {
      guard hasMorePages && !isLoading else { return }
    }

    if refresh {
      currentLoadID = UUID()
      currentPage = 0
      hasMorePages = true
    }

    let loadID = currentLoadID
    isLoading = true

    defer {
      if loadID == currentLoadID {
        withAnimation {
          isLoading = false
        }
      }
    }

    if AppConfig.isOffline {
      let series = KomgaSeriesStore.fetchCollectionSeries(
        context: context,
        collectionId: collectionId,
        page: currentPage,
        size: pageSize,
        browseOpts: browseOpts
      )
      guard loadID == currentLoadID else { return }
      let ids = series.map { $0.id }
      updateState(ids: ids, moreAvailable: ids.count == pageSize)
    } else {
      do {
        let page = try await SyncService.shared.syncCollectionSeries(
          collectionId: collectionId,
          page: currentPage,
          size: pageSize,
          browseOpts: browseOpts,
          libraryIds: libraryIds
        )

        guard loadID == currentLoadID else { return }
        let ids = page.content.map { $0.id }
        updateState(ids: ids, moreAvailable: !page.last)
      } catch {
        guard loadID == currentLoadID else { return }
        ErrorManager.shared.alert(error: error)
      }
    }
  }

  private func updateState(ids: [String], moreAvailable: Bool) {
    withAnimation {
      if currentPage == 0 {
        browseSeriesIds = ids
      } else {
        browseSeriesIds.append(contentsOf: ids)
      }
    }
    hasMorePages = moreAvailable
    currentPage += 1
  }
}
