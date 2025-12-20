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
          ForEach(Array(viewModel.browseBookIds.enumerated()), id: \.element) { index, bookId in
            BrowseBookItemView(
              bookId: bookId,
              instanceId: instanceId,
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
            .onAppear {
              if index >= viewModel.browseBookIds.count - 3 {
                Task {
                  await loadMore(false)
                }
              }
            }
          }
        }
      case .list:
        LazyVStack(spacing: layoutHelper.spacing) {
          ForEach(Array(viewModel.browseBookIds.enumerated()), id: \.element) { index, bookId in
            BrowseBookItemView(
              bookId: bookId,
              instanceId: instanceId,
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
            .onAppear {
              if index >= viewModel.browseBookIds.count - 3 {
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
  let bookId: String
  let instanceId: String
  let viewModel: BookViewModel
  let cardWidth: CGFloat
  let layout: BrowseLayoutMode
  let readerPresentation: ReaderPresentationManager
  let onBookUpdated: (() -> Void)?

  @Query private var books: [KomgaBook]

  init(
    bookId: String,
    instanceId: String,
    viewModel: BookViewModel,
    cardWidth: CGFloat,
    layout: BrowseLayoutMode,
    readerPresentation: ReaderPresentationManager,
    onBookUpdated: (() -> Void)?
  ) {
    self.bookId = bookId
    self.instanceId = instanceId
    self.viewModel = viewModel
    self.cardWidth = cardWidth
    self.layout = layout
    self.readerPresentation = readerPresentation
    self.onBookUpdated = onBookUpdated

    let compositeId = "\(instanceId)_\(bookId)"
    _books = Query(filter: #Predicate<KomgaBook> { $0.id == compositeId })
  }

  var body: some View {
    if let komgaBook = books.first {
      switch layout {
      case .grid:
        BookCardView(
          viewModel: viewModel,
          cardWidth: cardWidth,
          onReadBook: { incognito in
            readerPresentation.present(book: komgaBook.toBook(), incognito: incognito)
          },
          onBookUpdated: onBookUpdated,
          showSeriesTitle: true
        )
        .environment(komgaBook)
        .focusPadding()
      case .list:
        BookRowView(
          viewModel: viewModel,
          onReadBook: { incognito in
            readerPresentation.present(book: komgaBook.toBook(), incognito: incognito)
          },
          onBookUpdated: onBookUpdated,
          showSeriesTitle: true
        )
        .environment(komgaBook)
      }
    }
  }
}
