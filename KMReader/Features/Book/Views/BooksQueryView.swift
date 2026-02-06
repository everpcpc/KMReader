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
  let browseLayout: BrowseLayoutMode
  let viewModel: BookViewModel
  let loadMore: (Bool) async -> Void

  @AppStorage("gridDensity") private var gridDensity: Double = GridDensity.standard.rawValue
  @Query private var komgaBooks: [KomgaBook]

  private var columns: [GridItem] {
    LayoutConfig.adaptiveColumns(for: gridDensity)
  }

  private var spacing: CGFloat {
    LayoutConfig.spacing(for: gridDensity)
  }

  private var booksById: [String: KomgaBook] {
    komgaBooks.reduce(into: [:]) { result, book in
      result[book.bookId] = book
    }
  }

  init(
    browseOpts: BookBrowseOptions,
    browseLayout: BrowseLayoutMode,
    viewModel: BookViewModel,
    loadMore: @escaping (Bool) async -> Void
  ) {
    self.browseOpts = browseOpts
    self.browseLayout = browseLayout
    self.viewModel = viewModel
    self.loadMore = loadMore

    let compositeIds = viewModel.pagination.items.map { CompositeID.generate(id: $0.id) }
    _komgaBooks = Query(filter: #Predicate<KomgaBook> { compositeIds.contains($0.id) })
  }

  var body: some View {
    BrowseStateView(
      isLoading: viewModel.isLoading,
      isEmpty: viewModel.pagination.isEmpty,
      emptyIcon: ContentIcon.book,
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
        LazyVGrid(columns: columns, spacing: spacing) {
          ForEach(viewModel.pagination.items) { book in
            BookQueryItemView(
              bookId: book.id,
              layout: .grid,
              komgaBook: booksById[book.id],
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
        .padding(.horizontal)
      case .list:
        LazyVStack {
          ForEach(viewModel.pagination.items) { book in
            BookQueryItemView(
              bookId: book.id,
              layout: .list,
              komgaBook: booksById[book.id],
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
