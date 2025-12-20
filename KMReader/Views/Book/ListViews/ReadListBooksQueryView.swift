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
  let bookIds: [String]
  let bookViewModel: BookViewModel
  let onReadBook: (Book, Bool) -> Void
  let layoutHelper: BrowseLayoutHelper
  let browseLayout: BrowseLayoutMode
  let isSelectionMode: Bool
  @Binding var selectedBookIds: Set<String>
  let isAdmin: Bool
  let refreshBooks: () -> Void
  let loadMore: (Bool) async -> Void

  @Query private var books: [KomgaBook]

  init(
    readListId: String,
    bookIds: [String],
    bookViewModel: BookViewModel,
    onReadBook: @escaping (Book, Bool) -> Void,
    layoutHelper: BrowseLayoutHelper,
    browseLayout: BrowseLayoutMode,
    isSelectionMode: Bool,
    selectedBookIds: Binding<Set<String>>,
    isAdmin: Bool,
    refreshBooks: @escaping () -> Void,
    loadMore: @escaping (Bool) async -> Void
  ) {
    self.readListId = readListId
    self.bookIds = bookIds
    self.bookViewModel = bookViewModel
    self.onReadBook = onReadBook
    self.layoutHelper = layoutHelper
    self.browseLayout = browseLayout
    self.isSelectionMode = isSelectionMode
    self._selectedBookIds = selectedBookIds
    self.isAdmin = isAdmin
    self.refreshBooks = refreshBooks
    self.loadMore = loadMore

    let instanceId = AppConfig.currentInstanceId
    let predicate = #Predicate<KomgaBook> { book in
      book.instanceId == instanceId && bookIds.contains(book.bookId)
    }

    // Sorting read list books is usually by the order in bookIds or name
    _books = Query(filter: predicate, sort: [SortDescriptor(\.name, order: .forward)])
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
    if isSelectionMode && isAdmin {
      BookCardView(
        viewModel: bookViewModel,
        cardWidth: layoutHelper.cardWidth,
        onReadBook: { _ in },
        onBookUpdated: refreshBooks,
        showSeriesTitle: true
      )
      .environment(b)
      .focusPadding()
      .allowsHitTesting(false)
      .overlay(alignment: .topTrailing) {
        Image(systemName: selectedBookIds.contains(b.bookId) ? "checkmark.circle.fill" : "circle")
          .foregroundColor(selectedBookIds.contains(b.bookId) ? .accentColor : .secondary)
          .font(.title3)
          .padding(8)
          .background(Circle().fill(.ultraThinMaterial))
      }
      .contentShape(Rectangle())
      .highPriorityGesture(
        TapGesture().onEnded {
          withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            if selectedBookIds.contains(b.bookId) {
              selectedBookIds.remove(b.bookId)
            } else {
              selectedBookIds.insert(b.bookId)
            }
          }
        }
      )
    } else {
      if browseLayout == .grid {
        BookCardView(
          viewModel: bookViewModel,
          cardWidth: layoutHelper.cardWidth,
          onReadBook: { incognito in
            onReadBook(b.toBook(), incognito)
          },
          onBookUpdated: refreshBooks,
          showSeriesTitle: true
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
          showSeriesTitle: true
        )
        .environment(b)
      }
    }
  }
}
