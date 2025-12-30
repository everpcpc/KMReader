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
  let layoutHelper: BrowseLayoutHelper
  let browseLayout: BrowseLayoutMode
  let viewModel: BookViewModel
  let loadMore: (Bool) async -> Void

  var body: some View {
    BrowseStateView(
      isLoading: viewModel.isLoading,
      isEmpty: viewModel.pagination.isEmpty,
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
          ForEach(viewModel.pagination.items) { book in
            BookQueryItemView(
              bookId: book.id,
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
              if viewModel.pagination.shouldLoadMore(after: book) {
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
          ForEach(viewModel.pagination.items) { book in
            BookQueryItemView(
              bookId: book.id,
              cardWidth: layoutHelper.cardWidth,
              layout: .list,
              onBookUpdated: {
                Task {
                  await loadMore(true)
                }
              }
            )
            .onAppear {
              if viewModel.pagination.shouldLoadMore(after: book) {
                Task {
                  await loadMore(false)
                }
              }
            }
            if !viewModel.pagination.isLast(book) {
              Divider()
            }
          }
        }
        .padding(.horizontal)
      }
    }
  }
}
