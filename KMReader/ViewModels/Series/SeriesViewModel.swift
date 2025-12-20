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
  var series: [Series] = []
  var isLoading = false

  private let seriesService = SeriesService.shared
  private let sseService = SSEService.shared
  private var currentPage = 0
  private var hasMorePages = true
  private var currentState: SeriesBrowseOptions?
  private var currentSearchText: String = ""

  init() {
    setupSSEListeners()
  }

  private func setupSSEListeners() {
    // Series events
    sseService.onSeriesChanged = { [weak self] event in
      Task { @MainActor in
        // Update series in list if it exists
        if let index = self?.series.firstIndex(where: { $0.id == event.seriesId }) {
          if let updatedSeries = try? await self?.seriesService.getOneSeries(id: event.seriesId) {
            self?.series[index] = updatedSeries
          }
        }
      }
    }

    sseService.onSeriesDeleted = { [weak self] event in
      Task { @MainActor in
        // Remove series from list
        self?.series.removeAll { $0.id == event.seriesId }
      }
    }

    // Read progress series events
    sseService.onReadProgressSeriesChanged = { [weak self] event in
      Task { @MainActor in
        // Update series in list if it exists
        if let index = self?.series.firstIndex(where: { $0.id == event.seriesId }) {
          if let updatedSeries = try? await self?.seriesService.getOneSeries(id: event.seriesId) {
            self?.series[index] = updatedSeries
          }
        }
      }
    }
  }

  func loadSeries(
    browseOpts: SeriesBrowseOptions, searchText: String = "", libraryIds: [String]? = nil,
    refresh: Bool = false
  )
    async
  {
    // Check if parameters changed - if so, reset pagination
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

    // 1. Load from Local DB
    let localSeries = KomgaSeriesStore.shared.fetchSeries(
      libraryIds: libraryIds,
      page: currentPage,
      size: 20,
      sort: browseOpts.sortString,
      searchTerm: searchText.isEmpty ? nil : searchText
    )

    if !localSeries.isEmpty {
      if shouldReset {
        series = localSeries
      } else {
        series.append(contentsOf: localSeries)
      }
    }

    // 2. Sync with Server
    do {
      let page = try await SyncService.shared.syncSeriesPage(
        libraryIds: libraryIds,
        page: currentPage,
        size: 20,
        sort: browseOpts.sortString,
        searchTerm: searchText.isEmpty ? nil : searchText,
        browseOpts: browseOpts
      )

      withAnimation {
        if shouldReset {
          series = page.content
        } else {
          if !localSeries.isEmpty {
            // We already appended local data, replace it with fresh data
            let startIndex = series.count - localSeries.count
            if startIndex >= 0 {
              series.replaceSubrange(startIndex..<series.count, with: page.content)
            } else {
              series.append(contentsOf: page.content)
            }
          } else {
            series.append(contentsOf: page.content)
          }
        }
      }

      hasMorePages = !page.last
      currentPage += 1
    } catch {
      // If we have local data, we treat this as a silent failure (offline mode)
      // Only alert if we have no data to show
      if shouldReset && series.isEmpty {
        ErrorManager.shared.alert(error: error)
      }
    }

    isLoading = false
  }

  func loadNewSeries(libraryIds: [String]? = nil) async {
    isLoading = true

    do {
      let page = try await SyncService.shared.syncNewSeries(
        libraryIds: libraryIds, page: currentPage, size: 20)
      withAnimation {
        series = page.content
      }
    } catch {
      ErrorManager.shared.alert(error: error)
    }

    isLoading = false
  }

  func loadUpdatedSeries(libraryIds: [String]? = nil) async {
    isLoading = true

    do {
      let page = try await SyncService.shared.syncUpdatedSeries(
        libraryIds: libraryIds, page: currentPage, size: 20)
      withAnimation {
        series = page.content
      }
    } catch {
      ErrorManager.shared.alert(error: error)
    }

    isLoading = false
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
    guard hasMorePages && !isLoading else { return }

    isLoading = true

    // 1. Local Cache
    let localSeries = KomgaSeriesStore.shared.fetchCollectionSeries(
      collectionId: collectionId,
      page: currentPage,
      size: 20
    )
    if !localSeries.isEmpty {
      if refresh {
        series = localSeries
      } else {
        series.append(contentsOf: localSeries)
      }
    }

    // 2. Sync
    do {
      let page = try await SyncService.shared.syncCollectionSeries(
        collectionId: collectionId,
        page: currentPage,
        size: 20,
        browseOpts: browseOpts,
        libraryIds: libraryIds
      )

      withAnimation {
        if refresh {
          series = page.content
        } else {
          // Merge logic
          if !localSeries.isEmpty {
            let startIndex = series.count - localSeries.count
            if startIndex >= 0 {
              series.replaceSubrange(startIndex..<series.count, with: page.content)
            } else {
              series.append(contentsOf: page.content)
            }
          } else {
            series.append(contentsOf: page.content)
          }
        }
      }

      hasMorePages = !page.last
      currentPage += 1
    } catch {
      if series.isEmpty {
        ErrorManager.shared.alert(error: error)
      }
    }

    isLoading = false
  }
}
