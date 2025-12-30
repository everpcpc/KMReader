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
  let layoutHelper: BrowseLayoutHelper
  let browseLayout: BrowseLayoutMode
  let viewModel: SeriesViewModel
  let loadMore: (Bool) async -> Void

  var body: some View {
    BrowseStateView(
      isLoading: viewModel.isLoading,
      isEmpty: viewModel.pagination.isEmpty,
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
          ForEach(viewModel.pagination.items) { series in
            SeriesQueryItemView(
              seriesId: series.id,
              cardWidth: layoutHelper.cardWidth,
              layout: .grid,
              onActionCompleted: {
                Task {
                  await loadMore(true)
                }
              }
            )
            .padding(.bottom)
            .onAppear {
              if viewModel.pagination.shouldLoadMore(after: series) {
                Task {
                  await loadMore(false)
                }
              }
            }
          }
        }
        .padding(.horizontal, layoutHelper.spacing)
      case .list:
        LazyVStack {
          ForEach(viewModel.pagination.items) { series in
            SeriesQueryItemView(
              seriesId: series.id,
              cardWidth: layoutHelper.cardWidth,
              layout: .list,
              onActionCompleted: {
                Task {
                  await loadMore(true)
                }
              }
            )
            .onAppear {
              if viewModel.pagination.shouldLoadMore(after: series) {
                Task {
                  await loadMore(false)
                }
              }
            }
            if !viewModel.pagination.isLast(series) {
              Divider()
            }
          }
        }
        .padding(.horizontal)
      }
    }
  }
}
