//
// BooksBrowseView.swift
//
//

import SwiftUI

struct BooksBrowseView: View {
  let libraryIds: [String]
  let searchText: String
  let refreshTrigger: UUID
  let metadataFilter: MetadataFilterConfig?
  @Binding var showFilterSheet: Bool
  @Binding var showSavedFilters: Bool

  @AppStorage("bookBrowseOptions") private var storedBrowseOpts: BookBrowseOptions = BookBrowseOptions()
  @State private var browseOpts: BookBrowseOptions = BookBrowseOptions()
  @AppStorage("bookBrowseLayout") private var browseLayout: BrowseLayoutMode = .grid
  @AppStorage("searchIgnoreFilters") private var searchIgnoreFilters: Bool = false

  @State private var viewModel = BookViewModel()
  @State private var initializedKey: String?

  var body: some View {
    VStack {
      BookFilterView(
        browseOpts: $browseOpts,
        showFilterSheet: $showFilterSheet,
        showSavedFilters: $showSavedFilters,
        filterType: .books,
        libraryIds: libraryIds
      ).padding(.horizontal)

      BooksQueryView(
        libraryIds: libraryIds,
        searchText: searchText,
        browseOpts: effectiveBrowseOpts,
        browseLayout: browseLayout,
        viewModel: viewModel
      )
      .task(id: initializationKey) {
        guard initializedKey != initializationKey else { return }

        if let metadataFilter = metadataFilter {
          var opts = BookBrowseOptions()
          opts.metadataFilter = metadataFilter
          browseOpts = opts
        } else {
          browseOpts = storedBrowseOpts
        }
        initializedKey = initializationKey
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

  private var effectiveBrowseOpts: BookBrowseOptions {
    (searchIgnoreFilters && !searchText.isEmpty) ? BookBrowseOptions() : browseOpts
  }

  private var initializationKey: String {
    [
      libraryIds.joined(separator: ","),
      metadataFilter?.rawValue ?? "",
    ].joined(separator: "|")
  }

  private func loadBooks(refresh: Bool) async {
    await viewModel.loadBrowseBooks(
      browseOpts: effectiveBrowseOpts,
      searchText: searchText,
      libraryIds: libraryIds,
      refresh: refresh
    )
  }

}
