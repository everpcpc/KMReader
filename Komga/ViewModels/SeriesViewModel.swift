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
  private var currentState: BrowseOptions?

  func loadSeries(browseOpts: BrowseOptions, refresh: Bool = false) async {
    // Check if parameters changed - if so, reset pagination
    let paramsChanged =
      currentState?.libraryId != browseOpts.libraryId
      || currentState?.readStatusFilter != browseOpts.readStatusFilter
      || currentState?.seriesStatusFilter != browseOpts.seriesStatusFilter
      || currentState?.sortString != browseOpts.sortString

    let shouldReset = refresh || paramsChanged

    if shouldReset {
      currentPage = 0
      hasMorePages = true
      currentState = browseOpts
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
        seriesStatus: browseOpts.seriesStatusFilter
      )

      if shouldReset {
        series = page.content
      } else {
        series.append(contentsOf: page.content)
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
      series = page.content
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
      series = page.content
    } catch {
      errorMessage = error.localizedDescription
    }

    isLoading = false
  }

  func markAsRead(seriesId: String, browseOpts: BrowseOptions) async {
    do {
      try await seriesService.markAsRead(seriesId: seriesId)
      await loadSeries(browseOpts: browseOpts, refresh: true)
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  func markAsUnread(seriesId: String, browseOpts: BrowseOptions) async {
    do {
      try await seriesService.markAsUnread(seriesId: seriesId)
      await loadSeries(browseOpts: browseOpts, refresh: true)
    } catch {
      errorMessage = error.localizedDescription
    }
  }
}
