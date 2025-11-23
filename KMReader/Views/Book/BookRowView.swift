//
//  BookRowView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct BookRowView: View {
  let book: Book
  var viewModel: BookViewModel
  var onReadBook: ((Bool) -> Void)?
  var onBookUpdated: (() -> Void)? = nil
  var showSeriesTitle: Bool = false

  @State private var showReadListPicker = false
  @State private var showDeleteConfirmation = false

  private var thumbnailURL: URL? {
    BookService.shared.getBookThumbnailURL(id: book.id)
  }

  var completed: Bool {
    guard let readProgress = book.readProgress else { return false }
    return readProgress.completed
  }

  private var isInProgress: Bool {
    guard let readProgress = book.readProgress else { return false }
    return !readProgress.completed
  }

  var showTitle: Bool {
    showSeriesTitle && !book.seriesTitle.isEmpty
  }

  var bookTitleLineLimit: Int {
    showTitle ? 1 : 2
  }

  var body: some View {
    HStack(spacing: 12) {
      ThumbnailImage(url: thumbnailURL, showPlaceholder: false, width: 60, cornerRadius: 4)

      VStack(alignment: .leading, spacing: 4) {
        if showSeriesTitle && !book.seriesTitle.isEmpty {
          Text(book.seriesTitle)
            .font(.footnote)
            .foregroundColor(.secondary)
            .lineLimit(1)
        }

        Text("#\(formatNumber(book.number)) - \(book.metadata.title)")
          .font(.body)
          .foregroundColor(completed ? .secondary : .primary)
          .lineLimit(bookTitleLineLimit)

        HStack(spacing: 4) {
          if let releaseDate = book.metadata.releaseDate, !releaseDate.isEmpty {
            Label(releaseDate, systemImage: "calendar.badge.clock")
            Text("•")
          }
          Label(book.created.formatted(date: .abbreviated, time: .omitted), systemImage: "clock")
          if let progress = book.readProgress {
            Text("•")
            if progress.completed {
              Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
            } else {
              Text("Page \(progress.page + 1)")
                .foregroundColor(.blue)
            }
          }
        }
        .font(.caption)
        .foregroundColor(.secondary)

        Group {
          if book.deleted {
            Text("Unavailable")
              .foregroundColor(.red)
          } else {
            HStack(spacing: 4) {
              Text("\(book.media.pagesCount) pages")
              Text("•")
              Label(book.size, systemImage: "doc")
              if book.oneshot {
                Text("•")
                Text("Oneshot")
                  .foregroundColor(.blue)
              }
            }.foregroundColor(.secondary)
          }
        }.font(.footnote)
      }

      Spacer()

      Image(systemName: "chevron.right")
        .foregroundColor(.secondary)
    }
    .contentShape(Rectangle())
    .onTapGesture {
      onReadBook?(false)
    }
    .contextMenu {
      BookContextMenu(
        book: book,
        viewModel: viewModel,
        onReadBook: onReadBook,
        onActionCompleted: onBookUpdated,
        onShowReadListPicker: {
          showReadListPicker = true
        },
        onDeleteRequested: {
          showDeleteConfirmation = true
        }
      )
    }
    .alert("Delete Book", isPresented: $showDeleteConfirmation) {
      Button("Cancel", role: .cancel) {}
      Button("Delete", role: .destructive) {
        deleteBook()
      }
    } message: {
      Text("Are you sure you want to delete this book? This action cannot be undone.")
    }
    .sheet(isPresented: $showReadListPicker) {
      ReadListPickerSheet(
        bookIds: [book.id],
        onSelect: { readListId in
          addToReadList(readListId: readListId)
        },
        onComplete: {
          // Create already adds book, just refresh
          onBookUpdated?()
        }
      )
    }
  }

  private func addToReadList(readListId: String) {
    Task {
      do {
        try await ReadListService.shared.addBooksToReadList(
          readListId: readListId,
          bookIds: [book.id]
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

  private func deleteBook() {
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

  private func formatNumber(_ number: Double) -> String {
    if number.truncatingRemainder(dividingBy: 1) == 0 {
      return String(format: "%.0f", number)
    } else {
      return String(format: "%.1f", number)
    }
  }
}
