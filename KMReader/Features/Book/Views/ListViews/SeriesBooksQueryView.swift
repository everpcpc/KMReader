//
// SeriesBooksQueryView.swift
//
//

import SwiftUI

struct SeriesBooksQueryView: View {
  let seriesId: String
  let bookViewModel: BookViewModel
  let browseOpts: BookBrowseOptions
  let browseLayout: BrowseLayoutMode

  @AppStorage("gridDensity") private var gridDensity: Double = GridDensity.standard.rawValue

  private var columns: [GridItem] {
    LayoutConfig.adaptiveColumns(for: gridDensity)
  }

  private var spacing: CGFloat {
    LayoutConfig.spacing(for: gridDensity)
  }

  init(
    seriesId: String,
    bookViewModel: BookViewModel,
    browseOpts: BookBrowseOptions,
    browseLayout: BrowseLayoutMode,
  ) {
    self.seriesId = seriesId
    self.bookViewModel = bookViewModel
    self.browseOpts = browseOpts
    self.browseLayout = browseLayout
  }

  var body: some View {
    Group {
      if bookViewModel.isLoading && bookViewModel.pagination.isEmpty {
        ProgressView()
          .frame(maxWidth: .infinity)
          .padding()
      } else {
        switch browseLayout {
        case .grid:
          LazyVGrid(columns: columns, spacing: spacing) {
            ForEach(bookViewModel.pagination.items) { book in
              BookQueryItemView(
                bookId: book.id,
                layout: .grid,
                showSeriesTitle: false,
                showSeriesNavigation: false
              )
              .padding(.bottom)
              .onAppear {
                if bookViewModel.pagination.shouldLoadMore(after: book) {
                  loadBooks(refresh: false)
                }
              }
            }
          }
          .padding(.horizontal)
        case .list:
          LazyVStack {
            ForEach(bookViewModel.pagination.items) { book in
              BookQueryItemView(
                bookId: book.id,
                layout: .list,
                showSeriesTitle: false,
                showSeriesNavigation: false
              )
              .onAppear {
                if bookViewModel.pagination.shouldLoadMore(after: book) {
                  loadBooks(refresh: false)
                }
              }
              if !bookViewModel.pagination.isLast(book) {
                Divider()
              }
            }
          }
          .padding(.horizontal)
        }
      }
    }
  }

  private func loadBooks(refresh: Bool) {
    Task {
      await bookViewModel.loadSeriesBooks(
        seriesId: seriesId,
        browseOpts: browseOpts,
        refresh: refresh
      )
    }
  }
}
