//
//  BooksBrowseView.swift
//  Komga
//

import SwiftData
import SwiftUI

struct BooksBrowseView: View {
  let libraryIds: [String]
  let searchText: String
  let refreshTrigger: UUID
  let metadataFilter: MetadataFilterConfig?
  @Binding var showFilterSheet: Bool
  @Binding var showSavedFilters: Bool

  @Environment(ReaderPresentationManager.self) private var readerPresentation
  @Environment(\.modelContext) private var modelContext

  @AppStorage("bookBrowseOptions") private var storedBrowseOpts: BookBrowseOptions = BookBrowseOptions()
  @State private var browseOpts: BookBrowseOptions = BookBrowseOptions()
  @AppStorage("bookBrowseLayout") private var browseLayout: BrowseLayoutMode = .grid
  @AppStorage("searchIgnoreFilters") private var searchIgnoreFilters: Bool = false

  @State private var viewModel = BookViewModel()
  @State private var hasInitialized = false

  var body: some View {
    VStack(spacing: 0) {
      BookFilterView(
        browseOpts: $browseOpts,
        showFilterSheet: $showFilterSheet,
        showSavedFilters: $showSavedFilters,
        filterType: .books,
        libraryIds: libraryIds
      )
      .padding(.horizontal)
      .padding(.vertical, 4)

      BooksQueryView(
        browseOpts: (searchIgnoreFilters && !searchText.isEmpty) ? BookBrowseOptions() : browseOpts,
        browseLayout: browseLayout,
        viewModel: viewModel,
        loadMore: loadBooks
      )
      .task {
        if !hasInitialized {
          if let metadataFilter = metadataFilter {
            var opts = BookBrowseOptions()
            opts.metadataFilter = metadataFilter
            browseOpts = opts
          } else {
            browseOpts = storedBrowseOpts
          }
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
          if metadataFilter == nil {
            storedBrowseOpts = newValue
          }
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
      .onChange(of: searchText) { _, newValue in
        Task {
          await loadBooks(refresh: true)
        }
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
      refresh: refresh
    )
  }

}
