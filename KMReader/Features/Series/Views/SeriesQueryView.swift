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
  @Query private var komgaSeries: [KomgaSeries]

  private var columns: [GridItem] {
    LayoutConfig.adaptiveColumns(for: gridDensity)
  }

  private var spacing: CGFloat {
    LayoutConfig.spacing(for: gridDensity)
  }

  private var seriesById: [String: KomgaSeries] {
    komgaSeries.reduce(into: [:]) { result, series in
      result[series.seriesId] = series
    }
  }

  init(
    browseOpts: SeriesBrowseOptions,
    browseLayout: BrowseLayoutMode,
    viewModel: SeriesViewModel,
    loadMore: @escaping (Bool) async -> Void
  ) {
    self.browseOpts = browseOpts
    self.browseLayout = browseLayout
    self.viewModel = viewModel
    self.loadMore = loadMore

    let compositeIds = viewModel.pagination.items.map { CompositeID.generate(id: $0.id) }
    _komgaSeries = Query(filter: #Predicate<KomgaSeries> { compositeIds.contains($0.id) })
  }

  var body: some View {
    BrowseStateView(
      isLoading: viewModel.isLoading,
      isEmpty: viewModel.pagination.isEmpty,
      emptyIcon: ContentIcon.series,
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
        LazyVGrid(columns: columns, spacing: spacing) {
          ForEach(viewModel.pagination.items) { series in
            SeriesQueryItemView(
              seriesId: series.id,
              layout: .grid,
              komgaSeries: seriesById[series.id]
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
        .padding(.horizontal)
      case .list:
        LazyVStack {
          ForEach(viewModel.pagination.items) { series in
            SeriesQueryItemView(
              seriesId: series.id,
              layout: .list,
              komgaSeries: seriesById[series.id]
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
