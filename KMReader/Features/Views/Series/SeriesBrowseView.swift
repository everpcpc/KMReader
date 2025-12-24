//
//  SeriesBrowseView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftData
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
  @AppStorage("searchIgnoreFilters") private var searchIgnoreFilters: Bool = false

  @State private var viewModel = SeriesViewModel()
  @Environment(\.modelContext) private var modelContext

  var body: some View {
    VStack(spacing: 0) {
      SeriesFilterView(
        browseOpts: $browseOpts,
        showFilterSheet: $showFilterSheet,
        layoutMode: $browseLayout
      )
      .padding(layoutHelper.spacing)

      SeriesQueryView(
        browseOpts: (searchIgnoreFilters && !searchText.isEmpty)
          ? SeriesBrowseOptions() : browseOpts,
        searchText: searchText,
        libraryIds: dashboard.libraryIds,
        instanceId: AppConfig.currentInstanceId,
        layoutHelper: layoutHelper,
        browseLayout: browseLayout,
        viewModel: viewModel,
        loadMore: loadSeries
      )
    }
    .task {
      await loadSeries(refresh: true)
    }
    .onChange(of: refreshTrigger) { _, _ in
      Task {
        await loadSeries(refresh: true)
      }
    }
    .onChange(of: browseOpts) { oldValue, newValue in
      if oldValue != newValue {
        Task {
          await loadSeries(refresh: true)
        }
      }
    }
    .onChange(of: searchText) { _, newValue in
      Task {
        await loadSeries(refresh: true)
      }
    }
  }

  private func loadSeries(refresh: Bool) async {
    let effectiveBrowseOpts =
      (searchIgnoreFilters && !searchText.isEmpty) ? SeriesBrowseOptions() : browseOpts
    await viewModel.loadSeries(
      context: modelContext,
      browseOpts: effectiveBrowseOpts,
      searchText: searchText,
      libraryIds: dashboard.libraryIds,
      refresh: refresh
    )
  }
}
