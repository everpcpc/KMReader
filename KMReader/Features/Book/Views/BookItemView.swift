//
// BookItemView.swift
//
//

import SwiftUI

struct BookItemView: View {
  let item: BookDisplayItem
  let layout: BrowseLayoutMode
  let onReadBook: (Bool) -> Void
  var onMutationCompleted: (() -> Void)? = nil
  var showSeriesTitle: Bool = true
  var showSeriesNavigation: Bool = true

  @State private var showDeleteConfirmation = false

  var body: some View {
    Group {
      switch layout {
      case .grid:
        BookCardView(
          item: item,
          onReadBook: onReadBook,
          onMutationCompleted: onMutationCompleted,
          onDeleteRequested: {
            showDeleteConfirmation = true
          },
          showSeriesTitle: showSeriesTitle,
          showSeriesNavigation: showSeriesNavigation
        )
      case .list:
        BookRowView(
          item: item,
          onReadBook: onReadBook,
          onMutationCompleted: onMutationCompleted,
          onDeleteRequested: {
            showDeleteConfirmation = true
          },
          showSeriesTitle: showSeriesTitle,
          showSeriesNavigation: showSeriesNavigation
        )
      }
    }
    .alert("Delete Book", isPresented: $showDeleteConfirmation) {
      Button("Cancel", role: .cancel) {}
      Button("Delete", role: .destructive) {
        deleteBook()
      }
    } message: {
      Text("Are you sure you want to delete this book? This action cannot be undone.")
    }
  }

  private func deleteBook() {
    Task {
      do {
        try await BookDeletionService.deleteBook(item)
        ErrorManager.shared.notify(message: String(localized: "notification.book.deleted"))
        onMutationCompleted?()
      } catch {
        ErrorManager.shared.alert(error: error)
      }
    }
  }
}
