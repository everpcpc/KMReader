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
      isEmpty: viewModel.browseSeries.isEmpty,
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
          ForEach(Array(viewModel.browseSeries.enumerated()), id: \.element.id) { index, series in
            BrowseSeriesItemView(
              series: series,
              cardWidth: layoutHelper.cardWidth,
              layout: .grid,
              onActionCompleted: {
                Task {
                  await loadMore(true)
                }
              }
            )
            .onAppear {
              if index >= viewModel.browseSeries.count - 3 {
                Task {
                  await loadMore(false)
                }
              }
            }
          }
        }
      case .list:
        LazyVStack(spacing: layoutHelper.spacing) {
          ForEach(Array(viewModel.browseSeries.enumerated()), id: \.element.id) { index, series in
            BrowseSeriesItemView(
              series: series,
              cardWidth: layoutHelper.cardWidth,
              layout: .list,
              onActionCompleted: {
                Task {
                  await loadMore(true)
                }
              }
            )
            .onAppear {
              if index >= viewModel.browseSeries.count - 3 {
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
  @Bindable var series: KomgaSeries
  let cardWidth: CGFloat
  let layout: BrowseLayoutMode
  let onActionCompleted: (() -> Void)?

  var body: some View {
    NavigationLink(value: NavDestination.seriesDetail(seriesId: series.seriesId)) {
      switch layout {
      case .grid:
        SeriesCardView(
          komgaSeries: series,
          cardWidth: cardWidth,
          onActionCompleted: onActionCompleted
        )
      case .list:
        SeriesRowView(
          komgaSeries: series,
          onActionCompleted: onActionCompleted
        )
      }
    }
    .focusPadding()
    .adaptiveButtonStyle(.plain)
  }
}
