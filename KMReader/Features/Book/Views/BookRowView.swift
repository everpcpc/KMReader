//
//  BookRowView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftData
import SwiftUI

struct BookRowView: View {
  @Bindable var komgaBook: KomgaBook
  var onReadBook: ((Bool) -> Void)?
  var showSeriesTitle: Bool = false
  var showSeriesNavigation: Bool = true

  @State private var showReadListPicker = false
  @State private var showDeleteConfirmation = false
  @State private var showEditSheet = false

  var completed: Bool {
    guard let progressCompleted = komgaBook.progressCompleted else { return false }
    return progressCompleted
  }

  private var progress: Double {
    guard let progressPage = komgaBook.progressPage else { return 0 }
    guard komgaBook.mediaPagesCount > 0 else { return 0 }
    return Double(progressPage) / Double(komgaBook.mediaPagesCount)
  }

  private var isInProgress: Bool {
    guard let progressCompleted = komgaBook.progressCompleted else { return false }
    return !progressCompleted
  }

  var shouldShowSeriesTitle: Bool {
    return showSeriesTitle && !komgaBook.seriesTitle.isEmpty
  }

  var bookTitleLine: String {
    if komgaBook.oneshot {
      return komgaBook.metaTitle
    }
    return String("\(komgaBook.metaNumber) - \(komgaBook.metaTitle)")
  }

  var bookTitleLineLimit: Int {
    (shouldShowSeriesTitle || komgaBook.oneshot) ? 1 : 2
  }

  var body: some View {
    HStack(spacing: 12) {
      Button {
        onReadBook?(false)
      } label: {
        ThumbnailImage(id: komgaBook.bookId, type: .book, width: 60)
      }.adaptiveButtonStyle(.plain)

      VStack(alignment: .leading, spacing: 4) {
        Button {
          onReadBook?(false)
        } label: {
          VStack(alignment: .leading, spacing: 4) {
            if komgaBook.oneshot {
              Text("Oneshot")
                .font(.footnote)
                .foregroundColor(.blue)
            } else if shouldShowSeriesTitle {
              Text(komgaBook.seriesTitle)
                .font(.footnote)
                .foregroundColor(.secondary)
                .lineLimit(1)
            }
            Text("#\(komgaBook.metaNumber) - \(komgaBook.metaTitle)")
              .foregroundColor(completed ? .secondary : .primary)
              .lineLimit(bookTitleLineLimit)
          }
        }.adaptiveButtonStyle(.plain)

        HStack {
          VStack(alignment: .leading, spacing: 4) {
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
                  Image(systemName: "circle.righthalf.filled")
                    .foregroundColor(.blue)
                  Text("Page \(progressPage + 1)")
                    .foregroundColor(.blue)
                  Text("•")
                  Text("\(progress * 100, specifier: "%.0f")%")
                }
              }
            }
            .font(.caption)
            .foregroundColor(.secondary)

            HStack(spacing: 4) {
              if komgaBook.isUnavailable {
                Text("Unavailable")
                  .foregroundColor(.red)
              } else if komgaBook.media.status != .ready {
                Text(komgaBook.media.status.label)
                  .foregroundColor(komgaBook.media.status.color)
              } else {
                Label("\(komgaBook.mediaPagesCount) pages", systemImage: "book.pages")
                  .foregroundColor(.secondary)
                Text("•").foregroundColor(.secondary)
                Label(komgaBook.size, systemImage: "doc")
                  .foregroundColor(.secondary)
              }
            }.font(.footnote)
          }

          Spacer()

          if komgaBook.downloadStatus != .notDownloaded {
            Image(systemName: komgaBook.downloadStatus.displayIcon)
              .foregroundColor(komgaBook.downloadStatus.displayColor)
          }
          EllipsisMenuButton {
              BookContextMenu(
                book: komgaBook.toBook(),
                downloadStatus: komgaBook.downloadStatus,
                onReadBook: onReadBook,
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
              .id(komgaBook.bookId)
          }
        }
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
    .sheet(isPresented: $showReadListPicker) {
      ReadListPickerSheet(
        bookId: komgaBook.bookId,
        onSelect: { readListId in
          addToReadList(readListId: readListId)
        }
      )
    }
    .sheet(isPresented: $showEditSheet) {
      BookEditSheet(book: komgaBook.toBook())
    }

  }

  private func addToReadList(readListId: String) {
    Task {
      do {
        try await ReadListService.shared.addBooksToReadList(
          readListId: readListId,
          bookIds: [komgaBook.bookId]
        )
        ErrorManager.shared.notify(
          message: String(localized: "notification.book.booksAddedToReadList"))
      } catch {
        ErrorManager.shared.alert(error: error)
      }
    }
  }

  private func deleteBook() {
    Task {
      do {
        try await BookService.shared.deleteBook(bookId: komgaBook.bookId)
        await CacheManager.clearCache(forBookId: komgaBook.bookId)
        ErrorManager.shared.notify(message: String(localized: "notification.book.deleted"))
      } catch {
        ErrorManager.shared.alert(error: error)
      }
    }
  }
}
