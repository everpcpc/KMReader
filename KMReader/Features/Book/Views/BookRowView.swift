//
// BookRowView.swift
//
//

import SwiftUI

struct BookRowView: View {
  let book: Book
  let downloadStatus: DownloadStatus
  var onReadBook: ((Bool) -> Void)?
  var showSeriesTitle: Bool = false
  var showSeriesNavigation: Bool = true

  @State private var showReadListPicker = false
  @State private var showDeleteConfirmation = false
  @State private var showEditSheet = false

  var completed: Bool {
    guard let progressCompleted = book.readProgress?.completed else { return false }
    return progressCompleted
  }

  private var progress: Double {
    guard let progressPage = book.readProgress?.page else { return 0 }
    guard book.media.pagesCount > 0 else { return 0 }
    return Double(progressPage) / Double(book.media.pagesCount)
  }

  private var isInProgress: Bool {
    guard let progressCompleted = book.readProgress?.completed else { return false }
    return !progressCompleted
  }

  var shouldShowSeriesTitle: Bool {
    return showSeriesTitle && !book.seriesTitle.isEmpty
  }

  var bookTitleLine: String {
    if book.oneshot {
      return book.metadata.title
    }
    return String("\(book.metadata.number) - \(book.metadata.title)")
  }

  var bookTitleLineLimit: Int {
    (shouldShowSeriesTitle || book.oneshot) ? 1 : 2
  }

  var body: some View {
    HStack(spacing: 12) {
      Button {
        onReadBook?(false)
      } label: {
        ThumbnailImage(id: book.id, type: .book, width: 60)
      }.adaptiveButtonStyle(.plain)

      VStack(alignment: .leading, spacing: 4) {
        Button {
          onReadBook?(false)
        } label: {
          VStack(alignment: .leading, spacing: 4) {
            if book.oneshot {
              Text("Oneshot")
                .font(.footnote)
                .foregroundColor(.blue)
            } else if shouldShowSeriesTitle {
              Text(book.seriesTitle)
                .font(.footnote)
                .foregroundColor(.secondary)
                .lineLimit(1)
            }
            Text("#\(book.metadata.number) - \(book.metadata.title)")
              .foregroundColor(completed ? .secondary : .primary)
              .lineLimit(bookTitleLineLimit)
          }
        }.adaptiveButtonStyle(.plain)

        HStack {
          VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
              if let releaseDate = book.metadata.releaseDate, !releaseDate.isEmpty {
                Label(releaseDate, systemImage: "calendar")
              } else {
                Label(
                  book.created.formatted(date: .abbreviated, time: .omitted),
                  systemImage: "clock")
              }
              if let progressPage = book.readProgress?.page,
                let progressCompleted = book.readProgress?.completed
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
              if book.deleted {
                Text("Unavailable")
                  .foregroundColor(.red)
              } else if book.media.status != .ready {
                Text(book.media.status.label)
                  .foregroundColor(book.media.status.color)
              } else {
                Label("\(book.media.pagesCount) pages", systemImage: "book.pages")
                  .foregroundColor(.secondary)
                Text("•").foregroundColor(.secondary)
                Label(book.size, systemImage: "doc")
                  .foregroundColor(.secondary)
              }
            }.font(.footnote)
          }

          Spacer()

          if downloadStatus != .notDownloaded {
            Image(systemName: downloadStatus.displayIcon)
              .foregroundColor(downloadStatus.displayColor)
          }
          EllipsisMenuButton {
            BookContextMenu(
              book: book,
              downloadStatus: downloadStatus,
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
            .id(book.id)
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
        bookId: book.id,
        onSelect: { readListId in
          addToReadList(readListId: readListId)
        }
      )
    }
    .sheet(isPresented: $showEditSheet) {
      BookEditSheet(book: book)
    }

  }

  private func addToReadList(readListId: String) {
    Task {
      do {
        try await ReadListService.shared.addBooksToReadList(
          readListId: readListId,
          bookIds: [book.id]
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
        try await BookService.shared.deleteBook(bookId: book.id)
        await CacheManager.clearCache(forBookId: book.id)
        ErrorManager.shared.notify(message: String(localized: "notification.book.deleted"))
      } catch {
        ErrorManager.shared.alert(error: error)
      }
    }
  }
}
