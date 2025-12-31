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
  let browseLayout: BrowseLayoutMode
  let viewModel: SeriesViewModel
  let loadMore: (Bool) async -> Void

  @AppStorage("gridDensity") private var gridDensity: Double = GridDensity.standard.rawValue

  private var columns: [GridItem] {
    LayoutConfig.adaptiveColumns(for: gridDensity)
  }

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
        LazyVGrid(columns: columns, spacing: LayoutConfig.spacing) {
          ForEach(viewModel.pagination.items) { series in
            SeriesQueryItemView(
              seriesId: series.id,
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
        .padding(.horizontal, LayoutConfig.spacing)
      case .list:
        LazyVStack {
          ForEach(viewModel.pagination.items) { series in
            SeriesQueryItemView(
              seriesId: series.id,
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
