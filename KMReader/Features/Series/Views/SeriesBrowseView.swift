//
// SeriesBrowseView.swift
//
//

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

  @State private var browseOpts: SeriesBrowseOptions = SeriesBrowseOptions()
  @State private var viewModel = SeriesViewModel()
  @State private var initializedKey: String?

  var body: some View {
    VStack {
      SeriesFilterView(
        browseOpts: $browseOpts,
        showFilterSheet: $showFilterSheet,
        showSavedFilters: $showSavedFilters,
        libraryIds: libraryIds,
        usesRelevanceSort: usesRelevanceSort,
        ignoresFiltersForSearch: ignoresFiltersForSearch
      ).padding(.horizontal)

      SeriesQueryView(
        libraryIds: libraryIds,
        searchText: searchText,
        browseOpts: effectiveBrowseOpts,
        browseLayout: browseLayout,
        viewModel: viewModel
      )
    }
    .task(id: initializationKey) {
      guard initializedKey != initializationKey else { return }

      if let metadataFilter = metadataFilter {
        var opts = SeriesBrowseOptions()
        opts.metadataFilter = metadataFilter
        browseOpts = opts
      } else {
        browseOpts = storedBrowseOpts
      }
      initializedKey = initializationKey
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

  private var effectiveBrowseOpts: SeriesBrowseOptions {
    ignoresFiltersForSearch ? browseOpts.filtersCleared : browseOpts
  }

  private var usesRelevanceSort: Bool {
    !searchText.isEmpty
  }

  private var ignoresFiltersForSearch: Bool {
    searchIgnoreFilters && !searchText.isEmpty
  }

  private var initializationKey: String {
    [
      libraryIds.joined(separator: ","),
      metadataFilter?.rawValue ?? "",
    ].joined(separator: "|")
  }

  private func loadSeries(refresh: Bool) async {
    await viewModel.loadSeries(
      browseOpts: effectiveBrowseOpts,
      searchText: searchText,
      libraryIds: libraryIds,
      refresh: refresh
    )
  }
}
