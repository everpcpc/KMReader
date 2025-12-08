//
//  SeriesBrowseView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct SeriesBrowseView: View {
  let layoutHelper: BrowseLayoutHelper
  let searchText: String
  let refreshTrigger: UUID
  @Binding var showFilterSheet: Bool

  @AppStorage("seriesBrowseOptions") private var browseOpts: SeriesBrowseOptions =
    SeriesBrowseOptions()
  @AppStorage("dashboard") private var dashboard: DashboardConfiguration = DashboardConfiguration()
  @AppStorage("seriesBrowseLayout") private var browseLayout: BrowseLayoutMode = .grid

  @State private var viewModel = SeriesViewModel()

  var body: some View {
    VStack(spacing: 0) {
      SeriesFilterView(
        browseOpts: $browseOpts,
        showFilterSheet: $showFilterSheet,
        layoutMode: $browseLayout
      )
      .padding(layoutHelper.spacing)

      BrowseStateView(
        isLoading: viewModel.isLoading,
        isEmpty: viewModel.series.isEmpty,
        emptyIcon: "books.vertical",
        emptyTitle: "No series found",
        emptyMessage: "Try selecting a different library.",
        onRetry: {
          Task {
            await loadSeries(refresh: true)
          }
        }
      ) {
        switch browseLayout {
        case .grid:
          LazyVGrid(columns: layoutHelper.columns, spacing: layoutHelper.spacing) {
            ForEach(Array(viewModel.series.enumerated()), id: \.element.id) { index, series in
              NavigationLink(value: NavDestination.seriesDetail(seriesId: series.id)) {
                SeriesCardView(
                  series: series,
                  cardWidth: layoutHelper.cardWidth,
                  onActionCompleted: {
                    Task {
                      await loadSeries(refresh: true)
                    }
                  }
                )
              }
              .focusPadding()
              .adaptiveButtonStyle(.plain)
              .onAppear {
                if index >= viewModel.series.count - 3 {
                  Task {
                    await loadSeries(refresh: false)
                  }
                }
              }
            }
          }
        case .list:
          LazyVStack(spacing: layoutHelper.spacing) {
            ForEach(Array(viewModel.series.enumerated()), id: \.element.id) { index, series in
              NavigationLink(value: NavDestination.seriesDetail(seriesId: series.id)) {
                SeriesRowView(
                  series: series,
                  onActionCompleted: {
                    Task {
                      await loadSeries(refresh: true)
                    }
                  }
                )
              }
              .adaptiveButtonStyle(.plain)
              .onAppear {
                if index >= viewModel.series.count - 3 {
                  Task {
                    await loadSeries(refresh: false)
                  }
                }
              }
            }
          }
        }
      }
    }
    .task {
      if viewModel.series.isEmpty {
        await loadSeries(refresh: true)
      }
    }
    .onChange(of: refreshTrigger) { _, _ in
      Task {
        await loadSeries(refresh: true)
      }
    }
    .onChange(of: browseOpts) { _, newValue in
      Task {
        await loadSeries(refresh: true)
      }
    }
    .onChange(of: searchText) { _, newValue in
      Task {
        await loadSeries(refresh: true)
      }
    }
  }

  private func loadSeries(refresh: Bool) async {
    await viewModel.loadSeries(
      browseOpts: browseOpts,
      searchText: searchText,
      libraryIds: dashboard.libraryIds,
      refresh: refresh
    )
  }
}
