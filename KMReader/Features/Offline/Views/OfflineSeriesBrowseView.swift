//
//  OfflineSeriesBrowseView.swift
//  KMReader
//
//

import SwiftData
import SwiftUI

struct OfflineSeriesBrowseView: View {
  let libraryIds: [String]
  let searchText: String
  let refreshTrigger: UUID
  @Binding var showFilterSheet: Bool
  @Binding var showSavedFilters: Bool

  @AppStorage("offlineSeriesBrowseOptions") private var storedBrowseOpts: SeriesBrowseOptions =
    Self.defaultBrowseOptions
  @AppStorage("seriesBrowseLayout") private var browseLayout: BrowseLayoutMode = .grid
  @AppStorage("searchIgnoreFilters") private var searchIgnoreFilters: Bool = false

  @Environment(\.modelContext) private var modelContext

  @State private var browseOpts: SeriesBrowseOptions = Self.defaultBrowseOptions
  @State private var viewModel = SeriesViewModel()
  @State private var hasInitialized = false

  private static var defaultBrowseOptions: SeriesBrowseOptions {
    var options = SeriesBrowseOptions()
    options.sortField = .downloadDate
    options.sortDirection = .descending
    return options
  }

  var body: some View {
    VStack {
      SeriesFilterView(
        browseOpts: $browseOpts,
        showFilterSheet: $showFilterSheet,
        showSavedFilters: $showSavedFilters,
        libraryIds: libraryIds,
        includeOfflineSorts: true
      )
      .padding(.horizontal)

      SeriesQueryView(
        libraryIds: libraryIds,
        searchText: searchText,
        browseOpts: (searchIgnoreFilters && !searchText.isEmpty)
          ? SeriesBrowseOptions() : browseOpts,
        browseLayout: browseLayout,
        viewModel: viewModel,
        useLocalOnly: true,
        offlineOnly: true
      )
    }
    .task {
      if !hasInitialized {
        browseOpts = storedBrowseOpts
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
        storedBrowseOpts = newValue
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
    .onChange(of: searchText) { _, _ in
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
      refresh: refresh,
      useLocalOnly: true,
      offlineOnly: true
    )
  }

}
