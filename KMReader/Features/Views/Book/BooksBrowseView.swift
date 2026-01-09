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
  @Binding var showFilterSheet: Bool
  @Binding var showSavedFilters: Bool

  @AppStorage("bookBrowseOptions") private var browseOpts: BookBrowseOptions = BookBrowseOptions()
  @AppStorage("bookBrowseLayout") private var browseLayout: BrowseLayoutMode = .grid
  @AppStorage("searchIgnoreFilters") private var searchIgnoreFilters: Bool = false
  @State private var viewModel = BookViewModel()
  @Environment(ReaderPresentationManager.self) private var readerPresentation
  @Environment(\.modelContext) private var modelContext
  @State private var hasInitialized = false

  var body: some View {
    VStack(spacing: 0) {
      BookFilterView(
        browseOpts: $browseOpts,
        showFilterSheet: $showFilterSheet,
        showSavedFilters: $showSavedFilters,
        filterType: .books
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
        guard !hasInitialized else { return }
        hasInitialized = true
        await loadBooks(refresh: true)
      }
      .onChange(of: refreshTrigger) { _, _ in
        Task {
          await loadBooks(refresh: true)
        }
      }
      .onChange(of: browseOpts) { oldValue, newValue in
        if oldValue != newValue {
          Task {
            await loadBooks(refresh: true)
          }
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
