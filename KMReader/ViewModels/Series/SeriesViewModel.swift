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
    let paramsChanged =
      currentState?.readStatusFilter != browseOpts.readStatusFilter
      || currentState?.seriesStatusFilter != browseOpts.seriesStatusFilter
      || currentState?.sortString != browseOpts.sortString
      || currentSearchText != searchText

    let shouldReset = refresh || paramsChanged

    if shouldReset {
      currentPage = 0
      hasMorePages = true
      currentState = browseOpts
      currentSearchText = searchText
    }

    guard hasMorePages && !isLoading else { return }

    isLoading = true

    do {
      let page = try await seriesService.getSeries(
        libraryIds: libraryIds,
        page: currentPage,
        size: 20,
        sort: browseOpts.sortString,
        readStatus: browseOpts.readStatusFilter,
        seriesStatus: browseOpts.seriesStatusFilter,
        searchTerm: searchText.isEmpty ? nil : searchText
      )

      withAnimation {
        if shouldReset {
          series = page.content
        } else {
          series.append(contentsOf: page.content)
        }
      }

      hasMorePages = !page.last
      currentPage += 1
    } catch {
      ErrorManager.shared.alert(error: error)
    }

    isLoading = false
  }

  func loadNewSeries(libraryIds: [String]? = nil) async {
    isLoading = true

    do {
      let page = try await seriesService.getNewSeries(libraryIds: libraryIds, size: 20)
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
      let page = try await seriesService.getUpdatedSeries(libraryIds: libraryIds, size: 20)
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
      await MainActor.run {
        ErrorManager.shared.notify(message: "Series marked as read")
      }
      await loadSeries(browseOpts: browseOpts, searchText: currentSearchText, refresh: true)
    } catch {
      ErrorManager.shared.alert(error: error)
    }
  }

  func markAsUnread(seriesId: String, browseOpts: SeriesBrowseOptions) async {
    do {
      try await seriesService.markAsUnread(seriesId: seriesId)
      await MainActor.run {
        ErrorManager.shared.notify(message: "Series marked as unread")
      }
      await loadSeries(browseOpts: browseOpts, searchText: currentSearchText, refresh: true)
    } catch {
      ErrorManager.shared.alert(error: error)
    }
  }

  func loadCollectionSeries(
    collectionId: String,
    browseOpts: SeriesBrowseOptions,
    refresh: Bool = false
  ) async {
    if refresh {
      currentPage = 0
      hasMorePages = true
    } else {
      guard hasMorePages && !isLoading else { return }
    }

    isLoading = true

    do {
      let page = try await CollectionService.shared.getCollectionSeries(
        collectionId: collectionId,
        page: currentPage,
        size: 20,
        browseOpts: browseOpts
      )

      withAnimation {
        if refresh {
          series = page.content
        } else {
          series.append(contentsOf: page.content)
        }
      }

      hasMorePages = !page.last
      currentPage += 1
    } catch {
      ErrorManager.shared.alert(error: error)
    }

    isLoading = false
  }
}
