//
//  SeriesBooksQueryView.swift
//  KMReader
//
//  Created by Komga iOS Client
//

import SwiftUI

struct SeriesBooksQueryView: View {
  let seriesId: String
  let bookViewModel: BookViewModel
  let browseLayout: BrowseLayoutMode
  let refreshBooks: () -> Void
  let loadMore: (Bool) async -> Void

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
    browseLayout: BrowseLayoutMode,
    refreshBooks: @escaping () -> Void,
    loadMore: @escaping (Bool) async -> Void
  ) {
    self.seriesId = seriesId
    self.bookViewModel = bookViewModel
    self.browseLayout = browseLayout
    self.refreshBooks = refreshBooks
    self.loadMore = loadMore
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
                  Task { await loadMore(false) }
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
                  Task { await loadMore(false) }
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
}
