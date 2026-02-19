//
// BooksQueryView.swift
//
//

import SwiftData
import SwiftUI

struct BooksQueryView: View {
  let libraryIds: [String]
  let searchText: String
  let browseOpts: BookBrowseOptions
  let browseLayout: BrowseLayoutMode
  let viewModel: BookViewModel
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
    browseOpts: BookBrowseOptions,
    browseLayout: BrowseLayoutMode,
    viewModel: BookViewModel,
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
      emptyIcon: ContentIcon.book,
      emptyTitle: LocalizedStringKey("No books found"),
      emptyMessage: LocalizedStringKey("Try selecting a different library."),
      onRetry: {
        loadBooks(refresh: true)
      }
    ) {
      switch browseLayout {
      case .grid:
        LazyVGrid(columns: columns, spacing: spacing) {
          ForEach(viewModel.pagination.items) { book in
            BookQueryItemView(
              bookId: book.id,
              layout: .grid
            )
            .padding(.bottom)
            .onAppear {
              if viewModel.pagination.shouldLoadMore(after: book) {
                loadBooks(refresh: false)
              }
            }
          }
        }
        .padding(.horizontal)
      case .list:
        LazyVStack {
          ForEach(viewModel.pagination.items) { book in
            BookQueryItemView(
              bookId: book.id,
              layout: .list
            )
            .onAppear {
              if viewModel.pagination.shouldLoadMore(after: book) {
                loadBooks(refresh: false)
              }
            }
            if !viewModel.pagination.isLast(book) {
              Divider()
            }
          }
        }
        .padding(.horizontal)
      }
    }
  }

  private func loadBooks(refresh: Bool) {
    Task {
      await viewModel.loadBrowseBooks(
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
