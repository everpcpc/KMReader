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
  var errorMessage: String?

  private let seriesService = SeriesService.shared
  private var currentPage = 0
  private var hasMorePages = true
  private var currentState: SeriesBrowseOptions?
  private var currentSearchText: String = ""

  func loadSeries(browseOpts: SeriesBrowseOptions, searchText: String = "", refresh: Bool = false)
    async
  {
    // Check if parameters changed - if so, reset pagination
    let paramsChanged =
      currentState?.libraryId != browseOpts.libraryId
      || currentState?.readStatusFilter != browseOpts.readStatusFilter
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
    errorMessage = nil

    do {
      let page = try await seriesService.getSeries(
        libraryId: browseOpts.libraryId,
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
      errorMessage = error.localizedDescription
    }

    isLoading = false
  }

  func loadNewSeries(libraryId: String = "") async {
    isLoading = true
    errorMessage = nil

    do {
      let page = try await seriesService.getNewSeries(libraryId: libraryId, size: 20)
      withAnimation {
        series = page.content
      }
    } catch {
      errorMessage = error.localizedDescription
    }

    isLoading = false
  }

  func loadUpdatedSeries(libraryId: String = "") async {
    isLoading = true
    errorMessage = nil

    do {
      let page = try await seriesService.getUpdatedSeries(libraryId: libraryId, size: 20)
      withAnimation {
        series = page.content
      }
    } catch {
      errorMessage = error.localizedDescription
    }

    isLoading = false
  }

  func markAsRead(seriesId: String, browseOpts: SeriesBrowseOptions) async {
    do {
      try await seriesService.markAsRead(seriesId: seriesId)
      await loadSeries(browseOpts: browseOpts, searchText: currentSearchText, refresh: true)
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  func markAsUnread(seriesId: String, browseOpts: SeriesBrowseOptions) async {
    do {
      try await seriesService.markAsUnread(seriesId: seriesId)
      await loadSeries(browseOpts: browseOpts, searchText: currentSearchText, refresh: true)
    } catch {
      errorMessage = error.localizedDescription
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
    errorMessage = nil

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
      errorMessage = error.localizedDescription
    }

    isLoading = false
  }
}
