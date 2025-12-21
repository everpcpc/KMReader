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
  let onReadBook: (Book, Bool) -> Void
  let layoutHelper: BrowseLayoutHelper
  let browseLayout: BrowseLayoutMode
  let refreshBooks: () -> Void
  let loadMore: (Bool) async -> Void

  var body: some View {
    Group {
      if bookViewModel.isLoading && bookViewModel.browseBooks.isEmpty {
        ProgressView()
          .frame(maxWidth: .infinity)
          .padding()
      } else {
        switch browseLayout {
        case .grid:
          LazyVGrid(columns: layoutHelper.columns, spacing: layoutHelper.spacing) {
            ForEach(Array(bookViewModel.browseBooks.enumerated()), id: \.element.id) { index, b in
              BookCardView(
                viewModel: bookViewModel,
                cardWidth: layoutHelper.cardWidth,
                onReadBook: { incognito in
                  onReadBook(b.toBook(), incognito)
                },
                onBookUpdated: refreshBooks,
                showSeriesTitle: false,
                showSeriesNavigation: false
              )
              .environment(b)
              .focusPadding()
              .onAppear {
                if index >= bookViewModel.browseBooks.count - 3 {
                  Task { await loadMore(false) }
                }
              }
            }
          }
          .padding(layoutHelper.spacing)
        case .list:
          LazyVStack(spacing: layoutHelper.spacing) {
            ForEach(Array(bookViewModel.browseBooks.enumerated()), id: \.element.id) { index, b in
              BookRowView(
                viewModel: bookViewModel,
                onReadBook: { incognito in
                  onReadBook(b.toBook(), incognito)
                },
                onBookUpdated: refreshBooks,
                showSeriesTitle: false,
                showSeriesNavigation: false
              )
              .environment(b)
              .onAppear {
                if index >= bookViewModel.browseBooks.count - 3 {
                  Task { await loadMore(false) }
                }
              }
            }
          }
        }
      }
    }
  }
}
