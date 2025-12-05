//
//  BooksBrowseView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct BooksBrowseView: View {
  let layoutHelper: BrowseLayoutHelper
  let searchText: String
  let refreshTrigger: UUID
  @Binding var showFilterSheet: Bool

  @AppStorage("bookBrowseOptions") private var browseOpts: BookBrowseOptions = BookBrowseOptions()
  @AppStorage("dashboard") private var dashboard: DashboardConfiguration = DashboardConfiguration()
  @AppStorage("browseLayout") private var browseLayout: BrowseLayoutMode = .grid
  @State private var viewModel = BookViewModel()
  @Environment(ReaderPresentationManager.self) private var readerPresentation
  @State private var hasInitialized = false

  var body: some View {
    VStack(spacing: 0) {
      BookFilterView(browseOpts: $browseOpts, showFilterSheet: $showFilterSheet)
        .padding(layoutHelper.spacing)

      BrowseStateView(
        isLoading: viewModel.isLoading,
        isEmpty: viewModel.books.isEmpty,
        emptyIcon: "book",
        emptyTitle: "No books found",
        emptyMessage: "Try selecting a different library.",
        onRetry: {
          Task {
            await loadBooks(refresh: true)
          }
        }
      ) {
        switch browseLayout {
        case .grid:
          gridView
        case .list:
          listView
        }
      }
    }
    .task {
      if viewModel.books.isEmpty {
        await loadBooks(refresh: true)
      }
    }
    .onChange(of: refreshTrigger) { _, _ in
      Task {
        await loadBooks(refresh: true)
      }
    }
    .onChange(of: browseOpts) { _, newValue in
      Task {
        await loadBooks(refresh: true)
      }
    }
    .onChange(of: searchText) { _, newValue in
      Task {
        await loadBooks(refresh: true)
      }
    }
  }

  private var gridView: some View {
    LazyVGrid(columns: layoutHelper.columns, spacing: layoutHelper.spacing) {
      ForEach(Array(viewModel.books.enumerated()), id: \.element.id) { index, book in
        BookCardView(
          book: book,
          viewModel: viewModel,
          cardWidth: layoutHelper.cardWidth,
          onReadBook: { incognito in
            readerPresentation.present(book: book, incognito: incognito)
          },
          onBookUpdated: {
            Task {
              await loadBooks(refresh: true)
            }
          },
          showSeriesTitle: true,
        )
        .focusPadding()
        .onAppear {
          if index >= viewModel.books.count - 3 {
            Task {
              await loadBooks(refresh: false)
            }
          }
        }
      }
    }
  }

  private var listView: some View {
    LazyVStack(spacing: layoutHelper.spacing) {
      ForEach(Array(viewModel.books.enumerated()), id: \.element.id) { index, book in
        BookRowView(
          book: book,
          viewModel: viewModel,
          onReadBook: { incognito in
            readerPresentation.present(book: book, incognito: incognito)
          },
          onBookUpdated: {
            Task {
              await loadBooks(refresh: true)
            }
          },
          showSeriesTitle: true
        )
        .onAppear {
          if index >= viewModel.books.count - 3 {
            Task {
              await loadBooks(refresh: false)
            }
          }
        }
      }
    }
  }

  private func loadBooks(refresh: Bool) async {
    await viewModel.loadBrowseBooks(
      browseOpts: browseOpts,
      searchText: searchText,
      libraryIds: dashboard.libraryIds,
      refresh: refresh
    )
  }

}
