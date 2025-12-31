//
//  ReadListBooksQueryView.swift
//  KMReader
//
//  Created by Komga iOS Client
//

import SwiftData
import SwiftUI

struct ReadListBooksQueryView: View {
  let readListId: String
  @Bindable var bookViewModel: BookViewModel
  let browseOpts: ReadListBookBrowseOptions
  let layoutHelper: BrowseLayoutHelper
  let browseLayout: BrowseLayoutMode
  let isSelectionMode: Bool
  @Binding var selectedBookIds: Set<String>
  let isAdmin: Bool
  let refreshBooks: () -> Void

  @Environment(\.modelContext) private var modelContext

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
              Group {
                if isSelectionMode && isAdmin {
                  BookSelectionItemView(
                    bookId: book.id,
                    cardWidth: layoutHelper.cardWidth,
                    layout: .grid,
                    selectedBookIds: $selectedBookIds,
                    refreshBooks: refreshBooks,
                    showSeriesTitle: true
                  )
                } else {
                  BookQueryItemView(
                    bookId: book.id,
                    cardWidth: layoutHelper.cardWidth,
                    layout: .grid,
                    onBookUpdated: refreshBooks,
                    showSeriesTitle: true
                  )
                }
              }
              .padding(.bottom)
              .onAppear {
                if bookViewModel.pagination.shouldLoadMore(after: book) {
                  Task { await loadMore(refresh: false) }
                }
              }
            }
          }
          .padding(.horizontal, layoutHelper.spacing)
        case .list:
          LazyVStack {
            ForEach(bookViewModel.pagination.items) { book in
              Group {
                if isSelectionMode && isAdmin {
                  BookSelectionItemView(
                    bookId: book.id,
                    cardWidth: layoutHelper.cardWidth,
                    layout: .list,
                    selectedBookIds: $selectedBookIds,
                    refreshBooks: refreshBooks,
                    showSeriesTitle: true
                  )
                } else {
                  BookQueryItemView(
                    bookId: book.id,
                    cardWidth: layoutHelper.cardWidth,
                    layout: .list,
                    onBookUpdated: refreshBooks,
                    showSeriesTitle: true
                  )
                }
              }
              .onAppear {
                if bookViewModel.pagination.shouldLoadMore(after: book) {
                  Task { await loadMore(refresh: false) }
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

  private func loadMore(refresh: Bool) async {
    await bookViewModel.loadReadListBooks(
      context: modelContext,
      readListId: readListId,
      browseOpts: browseOpts,
      refresh: refresh
    )
  }
}
