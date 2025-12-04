//
//  BooksListViewForSeries.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

// Books list view for series detail
struct BooksListViewForSeries: View {
  let seriesId: String
  @Bindable var bookViewModel: BookViewModel
  var onReadBook: (Book, Bool) -> Void
  let layoutHelper: BrowseLayoutHelper
  @Binding var showFilterSheet: Bool

  @AppStorage("browseLayout") private var layoutMode: BrowseLayoutMode = .grid
  @AppStorage("seriesBookBrowseOptions") private var browseOpts: BookBrowseOptions =
    BookBrowseOptions()
  @AppStorage("dashboard") private var dashboard: DashboardConfiguration = DashboardConfiguration()

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Text("Books")
          .font(.headline)

        Spacer()

        BookFilterView(browseOpts: $browseOpts, showFilterSheet: $showFilterSheet)
      }

      if bookViewModel.isLoading && bookViewModel.books.isEmpty {
        ProgressView()
          .frame(maxWidth: .infinity)
          .padding()
      } else {
        Group {
          switch layoutMode {
          case .grid:
            LazyVGrid(columns: layoutHelper.columns, spacing: layoutHelper.spacing) {
              ForEach(bookViewModel.books) { book in
                BookCardView(
                  book: book,
                  viewModel: bookViewModel,
                  cardWidth: layoutHelper.cardWidth,
                  onBookUpdated: {
                    refreshBooks()
                  },
                  showSeriesTitle: false,
                )
                .focusPadding()
                .onAppear {
                  if book.id == bookViewModel.books.last?.id {
                    Task {
                      await bookViewModel.loadMoreBooks(
                        seriesId: seriesId, libraryIds: dashboard.libraryIds)
                    }
                  }
                }
              }
            }
            .padding(layoutHelper.spacing)
          case .list:
            LazyVStack(spacing: layoutHelper.spacing) {
              ForEach(bookViewModel.books) { book in
                BookRowView(
                  book: book,
                  viewModel: bookViewModel,
                  onReadBook: { incognito in
                    onReadBook(book, incognito)
                  },
                  onBookUpdated: {
                    refreshBooks()
                  },
                  showSeriesTitle: false,
                )
                .onAppear {
                  if book.id == bookViewModel.books.last?.id {
                    Task {
                      await bookViewModel.loadMoreBooks(
                        seriesId: seriesId, libraryIds: dashboard.libraryIds)
                    }
                  }
                }
              }
            }
          }
        }

        if bookViewModel.isLoading && !bookViewModel.books.isEmpty {
          ProgressView()
            .frame(maxWidth: .infinity)
            .padding()
        }
      }
    }
    .task(id: seriesId) {
      await bookViewModel.loadBooks(
        seriesId: seriesId, browseOpts: browseOpts, libraryIds: dashboard.libraryIds)
    }
    .onChange(of: browseOpts) {
      Task {
        await bookViewModel.loadBooks(
          seriesId: seriesId, browseOpts: browseOpts, libraryIds: dashboard.libraryIds)
      }
    }
  }
}

extension BooksListViewForSeries {
  fileprivate func refreshBooks() {
    Task {
      // Use refresh: false to preserve existing books during refresh for smoother UI
      await bookViewModel.loadBooks(
        seriesId: seriesId, browseOpts: browseOpts, libraryIds: dashboard.libraryIds, refresh: false
      )
    }
  }
}
