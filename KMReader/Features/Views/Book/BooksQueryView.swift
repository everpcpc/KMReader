//
//  BooksQueryView.swift
//  KMReader
//
//  Created by Komga iOS Client
//

import SwiftData
import SwiftUI

struct BooksQueryView: View {
  let browseOpts: BookBrowseOptions
  let searchText: String
  let libraryIds: [String]
  let instanceId: String
  let layoutHelper: BrowseLayoutHelper
  let browseLayout: BrowseLayoutMode
  let viewModel: BookViewModel
  let loadMore: (Bool) async -> Void

  var body: some View {
    BrowseStateView(
      isLoading: viewModel.isLoading,
      isEmpty: viewModel.browseBookIds.isEmpty,
      emptyIcon: "book",
      emptyTitle: LocalizedStringKey("No books found"),
      emptyMessage: LocalizedStringKey("Try selecting a different library."),
      onRetry: {
        Task {
          await loadMore(true)
        }
      }
    ) {
      switch browseLayout {
      case .grid:
        LazyVGrid(columns: layoutHelper.columns, spacing: layoutHelper.spacing) {
          ForEach(viewModel.browseBookIds, id: \.self) { bookId in
            BookQueryItemView(
              bookId: bookId,
              cardWidth: layoutHelper.cardWidth,
              layout: .grid,
              onBookUpdated: {
                Task {
                  await loadMore(true)
                }
              }
            )
            .padding(.bottom)
            .onAppear {
              if viewModel.browseBookIds.suffix(3).contains(bookId) {
                Task {
                  await loadMore(false)
                }
              }
            }
          }
        }
        .padding(.horizontal, layoutHelper.spacing)
      case .list:
        LazyVStack {
          ForEach(viewModel.browseBookIds, id: \.self) { bookId in
            BookQueryItemView(
              bookId: bookId,
              cardWidth: layoutHelper.cardWidth,
              layout: .list,
              onBookUpdated: {
                Task {
                  await loadMore(true)
                }
              }
            )
            .onAppear {
              if viewModel.browseBookIds.suffix(3).contains(bookId) {
                Task {
                  await loadMore(false)
                }
              }
            }
            if bookId != viewModel.browseBookIds.last {
              Divider()
            }
          }
        }
        .padding(.horizontal)
      }
    }
  }
}
