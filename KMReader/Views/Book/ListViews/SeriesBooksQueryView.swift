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

  @Query private var books: [KomgaBook]

  init(
    seriesId: String,
    bookViewModel: BookViewModel,
    onReadBook: @escaping (Book, Bool) -> Void,
    layoutHelper: BrowseLayoutHelper,
    browseLayout: BrowseLayoutMode,
    refreshBooks: @escaping () -> Void,
    loadMore: @escaping (Bool) async -> Void
  ) {
    self.seriesId = seriesId
    self.bookViewModel = bookViewModel
    self.onReadBook = onReadBook
    self.layoutHelper = layoutHelper
    self.browseLayout = browseLayout
    self.refreshBooks = refreshBooks
    self.loadMore = loadMore

    let instanceId = AppConfig.currentInstanceId
    let predicate = #Predicate<KomgaBook> { book in
      book.instanceId == instanceId && book.seriesId == seriesId
    }

    // Sorting series books is usually by number or name
    _books = Query(filter: predicate, sort: [SortDescriptor(\.number, order: .forward)])
  }

  var body: some View {
    Group {
      if bookViewModel.isLoading && books.isEmpty {
        ProgressView()
          .frame(maxWidth: .infinity)
          .padding()
      } else {
        switch browseLayout {
        case .grid:
          LazyVGrid(columns: layoutHelper.columns, spacing: layoutHelper.spacing) {
            ForEach(books) { b in
              bookItem(b)
                .onAppear {
                  if b.id == books.last?.id {
                    Task { await loadMore(false) }
                  }
                }
            }
          }
          .padding(layoutHelper.spacing)
        case .list:
          LazyVStack(spacing: layoutHelper.spacing) {
            ForEach(books) { b in
              bookItem(b)
                .onAppear {
                  if b.id == books.last?.id {
                    Task { await loadMore(false) }
                  }
                }
            }
          }
        }
      }
    }
  }

  @ViewBuilder
  private func bookItem(_ b: KomgaBook) -> some View {
    if browseLayout == .grid {
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
    } else {
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
    }
  }
}
