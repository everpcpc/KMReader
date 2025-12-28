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
      if bookViewModel.isLoading && bookViewModel.browseBookIds.isEmpty {
        ProgressView()
          .frame(maxWidth: .infinity)
          .padding()
      } else {
        switch browseLayout {
        case .grid:
          LazyVGrid(columns: layoutHelper.columns, spacing: layoutHelper.spacing) {
            ForEach(bookViewModel.browseBookIds, id: \.self) { bookId in
              BookQueryItemView(
                bookId: bookId,
                cardWidth: layoutHelper.cardWidth,
                layout: .grid,
                onBookUpdated: refreshBooks,
                showSeriesTitle: false,
                showSeriesNavigation: false
              )
              .padding(.bottom)
              .onAppear {
                if bookViewModel.browseBookIds.suffix(3).contains(bookId) {
                  Task { await loadMore(false) }
                }
              }
            }
          }
          .padding(.horizontal, layoutHelper.spacing)
        case .list:
          LazyVStack {
            ForEach(bookViewModel.browseBookIds, id: \.self) { bookId in
              BookQueryItemView(
                bookId: bookId,
                cardWidth: layoutHelper.cardWidth,
                layout: .list,
                onBookUpdated: refreshBooks,
                showSeriesTitle: false,
                showSeriesNavigation: false
              )
              .onAppear {
                if bookViewModel.browseBookIds.suffix(3).contains(bookId) {
                  Task { await loadMore(false) }
                }
              }
              if bookId != bookViewModel.browseBookIds.last {
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
