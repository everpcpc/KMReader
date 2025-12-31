//
//  SeriesBooksQueryView.swift
//  KMReader
//
//  Created by Komga iOS Client
//

import SwiftData
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

  var body: some View {
    Group {
      if bookViewModel.isLoading && bookViewModel.pagination.isEmpty {
        ProgressView()
          .frame(maxWidth: .infinity)
          .padding()
      } else {
        switch browseLayout {
        case .grid:
          LazyVGrid(columns: columns, spacing: LayoutConfig.spacing) {
            ForEach(bookViewModel.pagination.items) { book in
              BookQueryItemView(
                bookId: book.id,
                layout: .grid,
                onBookUpdated: refreshBooks,
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
          .padding(.horizontal, LayoutConfig.spacing)
        case .list:
          LazyVStack {
            ForEach(bookViewModel.pagination.items) { book in
              BookQueryItemView(
                bookId: book.id,
                layout: .list,
                onBookUpdated: refreshBooks,
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
