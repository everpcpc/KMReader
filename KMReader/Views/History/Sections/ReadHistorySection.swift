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

  @State private var readerState: BookReaderState?
  @State private var showReadListPicker = false
  @State private var selectedBookId: String?
  @State private var showDeleteConfirmation = false
  @State private var bookToDelete: Book?

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
            readerState = BookReaderState(bookId: book.id, incognito: false)
          } label: {
            ReadHistoryBookRow(book: book)
              .contentShape(Rectangle())
              .contextMenu {
                BookContextMenu(
                  book: book,
                  viewModel: bookViewModel,
                  onReadBook: { incognito in
                    readerState = BookReaderState(bookId: book.id, incognito: incognito)
                  },
                  onActionCompleted: onBookUpdated,
                  onShowReadListPicker: {
                    selectedBookId = book.id
                    showReadListPicker = true
                  },
                  onDeleteRequested: {
                    bookToDelete = book
                    showDeleteConfirmation = true
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
    .fullScreenCover(
      isPresented: isBookReaderPresented,
      onDismiss: {
        onBookUpdated?()
      }
    ) {
      if let state = readerState, let bookId = state.bookId {
        BookReaderView(bookId: bookId, incognito: state.incognito)
      }
    }
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
        await ImageCache.clearDiskCache(forBookId: book.id)
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
