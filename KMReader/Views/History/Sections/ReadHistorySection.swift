//
//  ReadHistorySection.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct ReadHistorySection: View {
  let title: String
  var bookViewModel: BookViewModel
  var onLoadMore: (() -> Void)?
  var onBookUpdated: (() -> Void)? = nil

  #if canImport(AppKit)
    @Environment(\.openWindow) private var openWindow
  #endif
  @State private var readerState: BookReaderState?
  @State private var showReadListPicker = false
  @State private var selectedBookId: String?
  @State private var showDeleteConfirmation = false
  @State private var bookToDelete: Book?
  @State private var downloadSheetBook: Book?

  private var isBookReaderPresented: Binding<Bool> {
    Binding(
      get: { readerState != nil },
      set: { if !$0 { readerState = nil } }
    )
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      LazyVStack(spacing: 12) {
        ForEach(Array(bookViewModel.books.enumerated()), id: \.element.id) { index, book in
          Button {
            readerState = BookReaderState(book: book, incognito: false)
          } label: {
            ReadHistoryBookRow(book: book)
              .contentShape(Rectangle())
              .contextMenu {
                BookContextMenu(
                  book: book,
                  viewModel: bookViewModel,
                  onReadBook: { incognito in
                    readerState = BookReaderState(book: book, incognito: incognito)
                  },
                  onActionCompleted: onBookUpdated,
                  onShowReadListPicker: {
                    selectedBookId = book.id
                    showReadListPicker = true
                  },
                  onDeleteRequested: {
                    bookToDelete = book
                    showDeleteConfirmation = true
                  },
                  onDownloadRequested: {
                    downloadSheetBook = book
                  }
                )
              }
          }
          .buttonStyle(.plain)
          .onAppear {
            // Load next page when the last few items appear
            if let onLoadMore = onLoadMore, index >= bookViewModel.books.count - 3 {
              onLoadMore()
            }
          }
        }

        if bookViewModel.isLoading {
          ProgressView()
            .frame(maxWidth: .infinity)
            .padding()
        }
      }
      .padding(.horizontal, 8)
    }
    .sheet(isPresented: $showReadListPicker) {
      if let bookId = selectedBookId {
        ReadListPickerSheet(
          bookIds: [bookId],
          onSelect: { readListId in
            addToReadList(bookId: bookId, readListId: readListId)
          },
          onComplete: {
            // Create already adds book, just refresh
            onBookUpdated?()
          }
        )
      }
    }
    #if canImport(UIKit)
      .fullScreenCover(
        isPresented: isBookReaderPresented,
        onDismiss: {
          onBookUpdated?()
        }
      ) {
        if let state = readerState, let book = state.book {
          BookReaderView(book: book, incognito: state.incognito)
        }
      }
    #else
      .onChange(of: readerState) { _, newState in
        if let state = newState, let book = state.book {
          ReaderWindowManager.shared.openReader(book: book, incognito: state.incognito)
          openWindow(id: "reader")
        } else {
          ReaderWindowManager.shared.closeReader()
        }
      }
    #endif
    .alert("Delete Book", isPresented: $showDeleteConfirmation) {
      Button("Cancel", role: .cancel) {
        bookToDelete = nil
      }
      Button("Delete", role: .destructive) {
        if let book = bookToDelete {
          deleteBook(book: book)
        }
        bookToDelete = nil
      }
    } message: {
      Text("Are you sure you want to delete this book? This action cannot be undone.")
    }
    .sheet(item: $downloadSheetBook) { book in
      BookDownloadSheet(book: book)
    }
  }

  private func addToReadList(bookId: String, readListId: String) {
    Task {
      do {
        try await ReadListService.shared.addBooksToReadList(
          readListId: readListId,
          bookIds: [bookId]
        )
        await MainActor.run {
          ErrorManager.shared.notify(message: "Books added to read list")
          onBookUpdated?()
        }
      } catch {
        await MainActor.run {
          ErrorManager.shared.alert(error: error)
        }
      }
    }
  }

  private func deleteBook(book: Book) {
    Task {
      do {
        try await BookService.shared.deleteBook(bookId: book.id)
        await CacheManager.clearCache(forBookId: book.id)
        await MainActor.run {
          ErrorManager.shared.notify(message: "Book deleted")
          onBookUpdated?()
        }
      } catch {
        await MainActor.run {
          ErrorManager.shared.alert(error: error)
        }
      }
    }
  }
}
