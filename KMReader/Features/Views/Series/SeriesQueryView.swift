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
            SeriesQueryItemView(
              seriesId: seriesId,
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
            SeriesQueryItemView(
              seriesId: seriesId,
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
