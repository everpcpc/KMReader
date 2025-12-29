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
  let layoutHelper: BrowseLayoutHelper
  let browseLayout: BrowseLayoutMode
  let refreshBooks: () -> Void
  let loadMore: (Bool) async -> Void

  var body: some View {
    Group {
      if bookViewModel.isLoading && bookViewModel.pagination.isEmpty {
        ProgressView()
          .frame(maxWidth: .infinity)
          .padding()
      } else {
        switch browseLayout {
        case .grid:
          LazyVGrid(columns: layoutHelper.columns, spacing: layoutHelper.spacing) {
            ForEach(bookViewModel.pagination.items) { book in
              BookQueryItemView(
                bookId: book.id,
                cardWidth: layoutHelper.cardWidth,
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
          .padding(.horizontal, layoutHelper.spacing)
        case .list:
          LazyVStack {
            ForEach(bookViewModel.pagination.items) { book in
              BookQueryItemView(
                bookId: book.id,
                cardWidth: layoutHelper.cardWidth,
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
