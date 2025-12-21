//
//  BookRowView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftData
import SwiftUI

struct BookRowView: View {
  @Environment(KomgaBook.self) private var komgaBook
  var viewModel: BookViewModel
  var onReadBook: ((Bool) -> Void)?
  var onBookUpdated: (() -> Void)? = nil
  var showSeriesTitle: Bool = false
  var showSeriesNavigation: Bool = true

  @State private var showReadListPicker = false
  @State private var showDeleteConfirmation = false
  @State private var showEditSheet = false

  var completed: Bool {
    guard let progressCompleted = komgaBook.progressCompleted else { return false }
    return progressCompleted
  }

  private var isInProgress: Bool {
    guard let progressCompleted = komgaBook.progressCompleted else { return false }
    return !progressCompleted
  }

  var shouldShowSeriesTitle: Bool {
    showSeriesTitle && !komgaBook.seriesTitle.isEmpty
  }

  var bookTitleLineLimit: Int {
    shouldShowSeriesTitle ? 1 : 2
  }

  var body: some View {
    Button {
      onReadBook?(false)
    } label: {
      HStack(spacing: 12) {
        ThumbnailImage(
          id: komgaBook.bookId, type: .book, showPlaceholder: false, width: 60, cornerRadius: 4)

        VStack(alignment: .leading, spacing: 4) {
          if shouldShowSeriesTitle {
            Text(komgaBook.seriesTitle)
              .font(.footnote)
              .foregroundColor(.secondary)
              .lineLimit(1)
          }

          Text("#\(komgaBook.metaNumber) - \(komgaBook.metaTitle)")
            .font(.body)
            .foregroundColor(completed ? .secondary : .primary)
            .lineLimit(bookTitleLineLimit)

          HStack(spacing: 4) {
            if let releaseDate = komgaBook.metaReleaseDate, !releaseDate.isEmpty {
              Label(releaseDate, systemImage: "calendar")
            } else {
              Label(
                komgaBook.created.formatted(date: .abbreviated, time: .omitted),
                systemImage: "clock")
            }
            if let progressPage = komgaBook.progressPage,
              let progressCompleted = komgaBook.progressCompleted
            {
              Text("•")
              if progressCompleted {
                Image(systemName: "checkmark.circle.fill")
                  .foregroundColor(.green)
              } else {
                Text("Page \(progressPage + 1)")
                  .foregroundColor(.blue)
              }
            }
          }
          .font(.caption)
          .foregroundColor(.secondary)

          Group {
            if komgaBook.deleted {
              Text("Unavailable")
                .foregroundColor(.red)
            } else {
              HStack(spacing: 4) {
                Label("\(komgaBook.mediaPagesCount) pages", systemImage: "book.pages")
                Text("•")
                Label(komgaBook.size, systemImage: "doc")
                if komgaBook.oneshot {
                  Text("•")
                  Text("Oneshot")
                    .foregroundColor(.blue)
                }
                if komgaBook.downloadStatus != .notDownloaded {
                  Text("•")
                  Image(systemName: komgaBook.downloadStatus.displayIcon)
                    .foregroundColor(komgaBook.downloadStatus.displayColor)
                    .frame(width: PlatformHelper.iconSize, height: PlatformHelper.iconSize)
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
    }
    .adaptiveButtonStyle(.plain)
    .contextMenu {
      BookContextMenu(
        viewModel: viewModel,
        onReadBook: onReadBook,
        onActionCompleted: onBookUpdated,
        onShowReadListPicker: {
          showReadListPicker = true
        },
        onDeleteRequested: {
          showDeleteConfirmation = true
        },
        onEditRequested: {
          showEditSheet = true
        },
        showSeriesNavigation: showSeriesNavigation
      )
      .environment(komgaBook)
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
        bookIds: [komgaBook.bookId],
        onSelect: { readListId in
          addToReadList(readListId: readListId)
        },
        onComplete: {
          // Create already adds book, just refresh
          onBookUpdated?()
        }
      )
    }
    .sheet(isPresented: $showEditSheet) {
      BookEditSheet(book: komgaBook.toBook())
        .onDisappear {
          onBookUpdated?()
        }
    }

  }

  private func addToReadList(readListId: String) {
    Task {
      do {
        try await ReadListService.shared.addBooksToReadList(
          readListId: readListId,
          bookIds: [komgaBook.bookId]
        )
        await MainActor.run {
          ErrorManager.shared.notify(
            message: String(localized: "notification.book.booksAddedToReadList"))
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
        try await BookService.shared.deleteBook(bookId: komgaBook.bookId)
        await CacheManager.clearCache(forBookId: komgaBook.bookId)
        await MainActor.run {
          ErrorManager.shared.notify(message: String(localized: "notification.book.deleted"))
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
