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
  var onReadBook: (String, Bool) -> Void
  let layoutMode: BrowseLayoutMode
  let layoutHelper: BrowseLayoutHelper

  @AppStorage("seriesBookBrowseOptions") private var browseOpts: BookBrowseOptions =
    BookBrowseOptions()

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Text("Books")
          .font(.headline)

        Spacer()

        BookFilterView(browseOpts: $browseOpts)
      }

      if bookViewModel.isLoading && bookViewModel.books.isEmpty {
        ProgressView()
          .frame(maxWidth: .infinity)
          .padding()
      } else {
        Group {
          switch layoutMode {
          case .grid:
            LazyVGrid(columns: layoutHelper.columns, spacing: 12) {
              ForEach(bookViewModel.books) { book in
                BookCardView(
                  book: book,
                  viewModel: bookViewModel,
                  cardWidth: layoutHelper.cardWidth,
                  onBookUpdated: {
                    refreshBooks()
                  }
                )
                .onAppear {
                  if book.id == bookViewModel.books.last?.id {
                    Task {
                      await bookViewModel.loadMoreBooks(seriesId: seriesId)
                    }
                  }
                }
              }
            }
            .padding(12)
          case .list:
            LazyVStack(spacing: 8) {
              ForEach(bookViewModel.books) { book in
                BookRowView(
                  book: book,
                  viewModel: bookViewModel,
                  onReadBook: { incognito in
                    onReadBook(book.id, incognito)
                  },
                  onBookUpdated: {
                    refreshBooks()
                  }
                )
                .onAppear {
                  if book.id == bookViewModel.books.last?.id {
                    Task {
                      await bookViewModel.loadMoreBooks(seriesId: seriesId)
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
      await bookViewModel.loadBooks(seriesId: seriesId, browseOpts: browseOpts)
    }
    .onChange(of: browseOpts) {
      Task {
        await bookViewModel.loadBooks(seriesId: seriesId, browseOpts: browseOpts)
      }
    }
  }
}

extension BooksListViewForSeries {
  fileprivate func refreshBooks() {
    Task {
      await bookViewModel.loadBooks(seriesId: seriesId, browseOpts: browseOpts)
    }
  }
}
