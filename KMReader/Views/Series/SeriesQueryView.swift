//
//  SeriesQueryView.swift
//  KMReader
//
//  Created by Komga iOS Client
//

import SwiftData
import SwiftUI

struct SeriesQueryView: View {
  let browseOpts: SeriesBrowseOptions
  let searchText: String
  let libraryIds: [String]
  let instanceId: String
  let layoutHelper: BrowseLayoutHelper
  let browseLayout: BrowseLayoutMode
  let viewModel: SeriesViewModel
  let loadMore: (Bool) async -> Void

  var body: some View {
    BrowseStateView(
      isLoading: viewModel.isLoading,
      isEmpty: viewModel.browseSeriesIds.isEmpty,
      emptyIcon: "books.vertical",
      emptyTitle: LocalizedStringKey("No series found"),
      emptyMessage: LocalizedStringKey("Try selecting a different library."),
      onRetry: {
        Task {
          await loadMore(true)
        }
      }
    ) {
      switch browseLayout {
      case .grid:
        LazyVGrid(columns: layoutHelper.columns, spacing: layoutHelper.spacing) {
          ForEach(Array(viewModel.browseSeriesIds.enumerated()), id: \.element) { index, seriesId in
            BrowseSeriesItemView(
              seriesId: seriesId,
              instanceId: instanceId,
              cardWidth: layoutHelper.cardWidth,
              layout: .grid,
              onActionCompleted: {
                Task {
                  await loadMore(true)
                }
              }
            )
            .onAppear {
              if index >= viewModel.browseSeriesIds.count - 3 {
                Task {
                  await loadMore(false)
                }
              }
            }
          }
        }
      case .list:
        LazyVStack(spacing: layoutHelper.spacing) {
          ForEach(Array(viewModel.browseSeriesIds.enumerated()), id: \.element) { index, seriesId in
            BrowseSeriesItemView(
              seriesId: seriesId,
              instanceId: instanceId,
              cardWidth: layoutHelper.cardWidth,
              layout: .list,
              onActionCompleted: {
                Task {
                  await loadMore(true)
                }
              }
            )
            .onAppear {
              if index >= viewModel.browseSeriesIds.count - 3 {
                Task {
                  await loadMore(false)
                }
              }
            }
          }
        }
      }
    }
  }
}

private struct BrowseSeriesItemView: View {
  let seriesId: String
  let instanceId: String
  let cardWidth: CGFloat
  let layout: BrowseLayoutMode
  let onActionCompleted: (() -> Void)?

  @Query private var seriesList: [KomgaSeries]

  init(
    seriesId: String,
    instanceId: String,
    cardWidth: CGFloat,
    layout: BrowseLayoutMode,
    onActionCompleted: (() -> Void)?
  ) {
    self.seriesId = seriesId
    self.instanceId = instanceId
    self.cardWidth = cardWidth
    self.layout = layout
    self.onActionCompleted = onActionCompleted

    let compositeId = "\(instanceId)_\(seriesId)"
    _seriesList = Query(filter: #Predicate<KomgaSeries> { $0.id == compositeId })
  }

  var body: some View {
    if let komgaSeries = seriesList.first {
      NavigationLink(value: NavDestination.seriesDetail(seriesId: komgaSeries.seriesId)) {
        switch layout {
        case .grid:
          SeriesCardView(
            cardWidth: cardWidth,
            onActionCompleted: onActionCompleted
          )
          .environment(komgaSeries)
        case .list:
          SeriesRowView(
            onActionCompleted: onActionCompleted
          )
          .environment(komgaSeries)
        }
      }
      .focusPadding()
      .adaptiveButtonStyle(.plain)
    }
  }
}
