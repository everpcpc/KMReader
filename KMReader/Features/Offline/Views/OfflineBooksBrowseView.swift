//
//  OfflineBooksBrowseView.swift
//  KMReader
//
//  Created by Komga iOS Client
//

import SwiftData
import SwiftUI

struct OfflineBooksBrowseView: View {
  let libraryIds: [String]
  let searchText: String
  let refreshTrigger: UUID
  @Binding var showFilterSheet: Bool
  @Binding var showSavedFilters: Bool

  @Environment(\.modelContext) private var modelContext

  @AppStorage("offlineBookBrowseOptions") private var storedBrowseOpts: BookBrowseOptions =
    Self.defaultBrowseOptions
  @AppStorage("bookBrowseLayout") private var browseLayout: BrowseLayoutMode = .grid
  @AppStorage("searchIgnoreFilters") private var searchIgnoreFilters: Bool = false

  @State private var browseOpts: BookBrowseOptions = Self.defaultBrowseOptions
  @State private var viewModel = BookViewModel()
  @State private var hasInitialized = false

  private static var defaultBrowseOptions: BookBrowseOptions {
    var options = BookBrowseOptions()
    options.sortField = .downloadDate
    options.sortDirection = .descending
    return options
  }

  var body: some View {
    VStack {
      BookFilterView(
        browseOpts: $browseOpts,
        showFilterSheet: $showFilterSheet,
        showSavedFilters: $showSavedFilters,
        filterType: .books,
        libraryIds: libraryIds,
        includeOfflineSorts: true
      )
      .padding(.horizontal)

      BooksQueryView(
        browseOpts: (searchIgnoreFilters && !searchText.isEmpty) ? BookBrowseOptions() : browseOpts,
        browseLayout: browseLayout,
        viewModel: viewModel,
        loadMore: loadBooks
      )
    }
    .task {
      if !hasInitialized {
        browseOpts = storedBrowseOpts
        hasInitialized = true
      }
      await loadBooks(refresh: true)
    }
    .onChange(of: refreshTrigger) { _, _ in
      Task {
        await loadBooks(refresh: true)
      }
    }
    .onChange(of: browseOpts) { oldValue, newValue in
      if oldValue != newValue {
        storedBrowseOpts = newValue
        Task {
          await loadBooks(refresh: true)
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
        await loadBooks(refresh: true)
      }
    }
  }

  private func loadBooks(refresh: Bool) async {
    let effectiveBrowseOpts =
      (searchIgnoreFilters && !searchText.isEmpty) ? BookBrowseOptions() : browseOpts

    await viewModel.loadBrowseBooks(
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
