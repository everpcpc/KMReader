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

  @Environment(ReaderPresentationManager.self) private var readerPresentation

  var body: some View {
    BrowseStateView(
      isLoading: viewModel.isLoading,
      isEmpty: viewModel.browseBooks.isEmpty,
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
          ForEach(Array(viewModel.browseBooks.enumerated()), id: \.element.id) { index, book in
            BrowseBookItemView(
              viewModel: viewModel,
              cardWidth: layoutHelper.cardWidth,
              layout: .grid,
              readerPresentation: readerPresentation,
              onBookUpdated: {
                Task {
                  await loadMore(true)
                }
              }
            )
            .environment(book)
            .onAppear {
              if index >= viewModel.browseBooks.count - 3 {
                Task {
                  await loadMore(false)
                }
              }
            }
          }
        }
      case .list:
        LazyVStack(spacing: layoutHelper.spacing) {
          ForEach(Array(viewModel.browseBooks.enumerated()), id: \.element.id) { index, book in
            BrowseBookItemView(
              viewModel: viewModel,
              cardWidth: layoutHelper.cardWidth,
              layout: .list,
              readerPresentation: readerPresentation,
              onBookUpdated: {
                Task {
                  await loadMore(true)
                }
              }
            )
            .environment(book)
            .onAppear {
              if index >= viewModel.browseBooks.count - 3 {
                Task {
                  await loadMore(false)
                }
              }
            }
          }
        }
      }
    }
  }
}

private struct BrowseBookItemView: View {
  @Environment(KomgaBook.self) private var book
  let viewModel: BookViewModel
  let cardWidth: CGFloat
  let layout: BrowseLayoutMode
  let readerPresentation: ReaderPresentationManager
  let onBookUpdated: (() -> Void)?

  var body: some View {
    switch layout {
    case .grid:
      BookCardView(
        viewModel: viewModel,
        cardWidth: cardWidth,
        onReadBook: { incognito in
          readerPresentation.present(book: book.toBook(), incognito: incognito)
        },
        onBookUpdated: onBookUpdated,
        showSeriesTitle: true
      )
      .focusPadding()
    case .list:
      BookRowView(
        viewModel: viewModel,
        onReadBook: { incognito in
          readerPresentation.present(book: book.toBook(), incognito: incognito)
        },
        onBookUpdated: onBookUpdated,
        showSeriesTitle: true
      )
    }
  }
}
