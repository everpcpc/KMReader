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

  @AppStorage("dashboard") private var dashboard: DashboardConfiguration = DashboardConfiguration()
  @Environment(\.modelContext) private var modelContext

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
            ForEach(Array(bookViewModel.browseBookIds.enumerated()), id: \.element) {
              index, bookId in
              Group {
                if isSelectionMode && isAdmin {
                  BookSelectionItemView(
                    bookId: bookId,
                    cardWidth: layoutHelper.cardWidth,
                    layout: .grid,
                    selectedBookIds: $selectedBookIds,
                    refreshBooks: refreshBooks,
                    showSeriesTitle: true
                  )
                } else {
                  BookQueryItemView(
                    bookId: bookId,
                    cardWidth: layoutHelper.cardWidth,
                    layout: .grid,
                    onBookUpdated: refreshBooks,
                    showSeriesTitle: true
                  )
                }
              }
              .padding(.bottom)
              .onAppear {
                if index >= bookViewModel.browseBookIds.count - 3 {
                  Task { await loadMore(refresh: false) }
                }
              }
            }
          }
          .padding(.horizontal, layoutHelper.spacing)
        case .list:
          LazyVStack {
            ForEach(Array(bookViewModel.browseBookIds.enumerated()), id: \.element) {
              index, bookId in
              Group {
                if isSelectionMode && isAdmin {
                  BookSelectionItemView(
                    bookId: bookId,
                    cardWidth: layoutHelper.cardWidth,
                    layout: .list,
                    selectedBookIds: $selectedBookIds,
                    refreshBooks: refreshBooks,
                    showSeriesTitle: true
                  )
                } else {
                  BookQueryItemView(
                    bookId: bookId,
                    cardWidth: layoutHelper.cardWidth,
                    layout: .list,
                    onBookUpdated: refreshBooks,
                    showSeriesTitle: true
                  )
                }
              }
              .onAppear {
                if index >= bookViewModel.browseBookIds.count - 3 {
                  Task { await loadMore(refresh: false) }
                }
              }
              if index < bookViewModel.browseBookIds.count - 1 {
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
      libraryIds: dashboard.libraryIds,
      refresh: refresh
    )
  }
}
