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

  private let seriesService = SeriesService.shared
  private(set) var pagination = PaginationState<IdentifiedString>(pageSize: 50)
  private var currentState: SeriesBrowseOptions?
  private var currentSearchText: String = ""
  private var currentMetadataFilter: MetadataFilterConfig?

  func loadSeries(
    context: ModelContext,
    browseOpts: SeriesBrowseOptions,
    searchText: String = "",
    libraryIds: [String]? = nil,
    metadataFilter: MetadataFilterConfig? = nil,
    refresh: Bool = false
  ) async {
    let paramsChanged =
      currentState != browseOpts || currentSearchText != searchText || currentMetadataFilter != metadataFilter
    let shouldReset = refresh || paramsChanged

    if !shouldReset {
      guard pagination.hasMorePages && !isLoading else { return }
    }

    if shouldReset {
      pagination.reset()
      currentState = browseOpts
      currentSearchText = searchText
      currentMetadataFilter = metadataFilter
    }

    let loadID = pagination.loadID
    isLoading = true

    defer {
      if loadID == pagination.loadID {
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
        offset: pagination.currentPage * pagination.pageSize,
        limit: pagination.pageSize
      )
      guard loadID == pagination.loadID else { return }
      applyPage(ids: ids, moreAvailable: ids.count == pagination.pageSize)
    } else {
      do {
        let page = try await SyncService.shared.syncSeriesPage(
          libraryIds: libraryIds,
          page: pagination.currentPage,
          size: pagination.pageSize,
          sort: browseOpts.sortString,
          searchTerm: searchText.isEmpty ? nil : searchText,
          browseOpts: browseOpts,
          metadataFilter: metadataFilter
        )

        guard loadID == pagination.loadID else { return }
        let ids = page.content.map { $0.id }
        applyPage(ids: ids, moreAvailable: !page.last)
      } catch {
        guard loadID == pagination.loadID else { return }
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

  func markAsUnread(seriesId: String, context: ModelContext, browseOpts: SeriesBrowseOptions) async {
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
      guard pagination.hasMorePages && !isLoading else { return }
    }

    if refresh {
      pagination.reset()
    }

    let loadID = pagination.loadID
    isLoading = true

    defer {
      if loadID == pagination.loadID {
        withAnimation {
          isLoading = false
        }
      }
    }

    if AppConfig.isOffline {
      let series = KomgaSeriesStore.fetchCollectionSeries(
        context: context,
        collectionId: collectionId,
        page: pagination.currentPage,
        size: pagination.pageSize,
        browseOpts: browseOpts
      )
      guard loadID == pagination.loadID else { return }
      let ids = series.map { $0.id }
      applyPage(ids: ids, moreAvailable: ids.count == pagination.pageSize)
    } else {
      do {
        let page = try await SyncService.shared.syncCollectionSeries(
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
}
