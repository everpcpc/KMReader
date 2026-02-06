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
  let browseLayout: BrowseLayoutMode
  let isSelectionMode: Bool
  @Binding var selectedBookIds: Set<String>
  let isAdmin: Bool
  let refreshBooks: () -> Void

  @AppStorage("gridDensity") private var gridDensity: Double = GridDensity.standard.rawValue
  @Environment(\.modelContext) private var modelContext
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
    readListId: String,
    bookViewModel: BookViewModel,
    browseOpts: ReadListBookBrowseOptions,
    browseLayout: BrowseLayoutMode,
    isSelectionMode: Bool,
    selectedBookIds: Binding<Set<String>>,
    isAdmin: Bool,
    refreshBooks: @escaping () -> Void
  ) {
    self.readListId = readListId
    self.bookViewModel = bookViewModel
    self.browseOpts = browseOpts
    self.browseLayout = browseLayout
    self.isSelectionMode = isSelectionMode
    self._selectedBookIds = selectedBookIds
    self.isAdmin = isAdmin
    self.refreshBooks = refreshBooks

    let compositeIds = bookViewModel.pagination.items.map { CompositeID.generate(id: $0.id) }
    _komgaBooks = Query(filter: #Predicate<KomgaBook> { compositeIds.contains($0.id) })
  }

  var body: some View {
    Group {
      if bookViewModel.isLoading && bookViewModel.pagination.isEmpty {
        ProgressView()
          .frame(maxWidth: .infinity)
          .padding()
      } else {
        switch browseLayout {
        case .grid:
          LazyVGrid(columns: columns, spacing: spacing) {
            ForEach(bookViewModel.pagination.items) { book in
              Group {
                if isSelectionMode && isAdmin {
                  BookSelectionItemView(
                    bookId: book.id,
                    layout: .grid,
                    komgaBook: booksById[book.id],
                    selectedBookIds: $selectedBookIds,
                    refreshBooks: refreshBooks,
                    showSeriesTitle: true
                  )
                } else {
                  BookQueryItemView(
                    bookId: book.id,
                    layout: .grid,
                    komgaBook: booksById[book.id],
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
          .padding(.horizontal)
        case .list:
          LazyVStack {
            ForEach(bookViewModel.pagination.items) { book in
              Group {
                if isSelectionMode && isAdmin {
                  BookSelectionItemView(
                    bookId: book.id,
                    layout: .list,
                    komgaBook: booksById[book.id],
                    selectedBookIds: $selectedBookIds,
                    refreshBooks: refreshBooks,
                    showSeriesTitle: true
                  )
                } else {
                  BookQueryItemView(
                    bookId: book.id,
                    layout: .list,
                    komgaBook: booksById[book.id],
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
