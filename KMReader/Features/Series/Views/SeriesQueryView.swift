//
// SeriesQueryView.swift
//
//

import SwiftData
import SwiftUI

struct SeriesQueryView: View {
  let libraryIds: [String]
  let searchText: String
  let browseOpts: SeriesBrowseOptions
  let browseLayout: BrowseLayoutMode
  let viewModel: SeriesViewModel
  let useLocalOnly: Bool
  let offlineOnly: Bool

  @AppStorage("gridDensity") private var gridDensity: Double = GridDensity.standard.rawValue
  @Environment(\.modelContext) private var modelContext

  private var columns: [GridItem] {
    LayoutConfig.adaptiveColumns(for: gridDensity)
  }

  private var spacing: CGFloat {
    LayoutConfig.spacing(for: gridDensity)
  }

  init(
    libraryIds: [String],
    searchText: String,
    browseOpts: SeriesBrowseOptions,
    browseLayout: BrowseLayoutMode,
    viewModel: SeriesViewModel,
    useLocalOnly: Bool = false,
    offlineOnly: Bool = false
  ) {
    self.libraryIds = libraryIds
    self.searchText = searchText
    self.browseOpts = browseOpts
    self.browseLayout = browseLayout
    self.viewModel = viewModel
    self.useLocalOnly = useLocalOnly
    self.offlineOnly = offlineOnly
  }

  var body: some View {
    BrowseStateView(
      isLoading: viewModel.isLoading,
      isEmpty: viewModel.pagination.isEmpty,
      emptyIcon: ContentIcon.series,
      emptyTitle: LocalizedStringKey("No series found"),
      emptyMessage: LocalizedStringKey("Try selecting a different library."),
      onRetry: {
        loadSeries(refresh: true)
      }
    ) {
      switch browseLayout {
      case .grid:
        LazyVGrid(columns: columns, spacing: spacing) {
          ForEach(viewModel.pagination.items) { series in
            SeriesQueryItemView(
              seriesId: series.id,
              layout: .grid
            )
            .padding(.bottom)
            .onAppear {
              if viewModel.pagination.shouldLoadMore(after: series) {
                loadSeries(refresh: false)
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
              layout: .list
            )
            .onAppear {
              if viewModel.pagination.shouldLoadMore(after: series) {
                loadSeries(refresh: false)
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

  private func loadSeries(refresh: Bool) {
    Task {
      await viewModel.loadSeries(
        context: modelContext,
        browseOpts: browseOpts,
        searchText: searchText,
        libraryIds: libraryIds,
        refresh: refresh,
        useLocalOnly: useLocalOnly,
        offlineOnly: offlineOnly
      )
    }
  }
}
