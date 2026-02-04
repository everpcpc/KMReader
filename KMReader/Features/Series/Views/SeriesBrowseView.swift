//
//  SeriesBrowseView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftData
import SwiftUI

struct SeriesBrowseView: View {
  let libraryIds: [String]
  let searchText: String
  let refreshTrigger: UUID
  let metadataFilter: MetadataFilterConfig?
  @Binding var showFilterSheet: Bool
  @Binding var showSavedFilters: Bool

  @AppStorage("seriesBrowseOptions") private var storedBrowseOpts: SeriesBrowseOptions = SeriesBrowseOptions()
  @AppStorage("seriesBrowseLayout") private var browseLayout: BrowseLayoutMode = .grid
  @AppStorage("searchIgnoreFilters") private var searchIgnoreFilters: Bool = false

  @Environment(\.modelContext) private var modelContext

  @State private var browseOpts: SeriesBrowseOptions = SeriesBrowseOptions()
  @State private var viewModel = SeriesViewModel()
  @State private var hasInitialized = false

  var body: some View {
    VStack {
      SeriesFilterView(
        browseOpts: $browseOpts,
        showFilterSheet: $showFilterSheet,
        showSavedFilters: $showSavedFilters,
        libraryIds: libraryIds
      ).padding(.horizontal)

      SeriesQueryView(
        browseOpts: (searchIgnoreFilters && !searchText.isEmpty)
          ? SeriesBrowseOptions() : browseOpts,
        browseLayout: browseLayout,
        viewModel: viewModel,
        loadMore: loadSeries
      )
    }
    .task {
      if !hasInitialized {
        if let metadataFilter = metadataFilter {
          var opts = SeriesBrowseOptions()
          opts.metadataFilter = metadataFilter
          browseOpts = opts
        } else {
          browseOpts = storedBrowseOpts
        }
        hasInitialized = true
      }
      await loadSeries(refresh: true)
    }
    .onChange(of: refreshTrigger) { _, _ in
      Task {
        await loadSeries(refresh: true)
      }
    }
    .onChange(of: browseOpts) { oldValue, newValue in
      if oldValue != newValue {
        if metadataFilter == nil {
          storedBrowseOpts = newValue
        }
        Task {
          await loadSeries(refresh: true)
        }
      }
    }
    .onChange(of: storedBrowseOpts) { _, newValue in
      if browseOpts != newValue {
        browseOpts = newValue
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
      libraryIds: libraryIds,
      refresh: refresh
    )
  }
}
