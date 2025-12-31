//
//  BookCardView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftData
import SwiftUI

struct BookCardView: View {
  @Bindable var komgaBook: KomgaBook
  let cardWidth: CGFloat
  var onReadBook: ((Bool) -> Void)? = nil
  var onBookUpdated: (() -> Void)? = nil
  var showSeriesTitle: Bool = false
  var showSeriesNavigation: Bool = true

  @AppStorage("showBookCardSeriesTitle") private var showBookCardSeriesTitle: Bool = true
  @AppStorage("coverOnlyCards") private var coverOnlyCards: Bool = false
  @State private var showReadListPicker = false
  @State private var showDeleteConfirmation = false
  @State private var showEditSheet = false

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
    return showSeriesTitle && showBookCardSeriesTitle && !komgaBook.seriesTitle.isEmpty
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
    VStack(alignment: .leading, spacing: 12) {
      Button {
        onReadBook?(false)
      } label: {
        ThumbnailImage(
          id: komgaBook.bookId, type: .book, shadowStyle: .platform, width: cardWidth,
          alignment: .bottom
        ) {
          ZStack {
            if let progressCompleted = komgaBook.progressCompleted {
              if !progressCompleted {
                ReadingProgressBar(progress: progress)
                  .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                  .padding(2)
              }
            } else {
              UnreadIndicator()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            }
          }
        }
      }
      .focusPadding()
      .adaptiveButtonStyle(.plain)
      .contextMenu {
        BookContextMenu(
          komgaBook: komgaBook,
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
      }

      if !coverOnlyCards {
        VStack(alignment: .leading) {
          if komgaBook.oneshot {
            Text("Oneshot")
              .font(.caption)
              .foregroundColor(.blue)
              .lineLimit(1)
          } else if shouldShowSeriesTitle {
            Text(komgaBook.seriesTitle)
              .font(.caption)
              .foregroundColor(.secondary)
              .lineLimit(1)
          }

          Text(bookTitleLine)
            .lineLimit(bookTitleLineLimit)

          HStack(spacing: 4) {
            if komgaBook.isUnavailable {
              Text("Unavailable")
                .foregroundColor(.red)
            } else if komgaBook.media.status != .ready {
              Text(komgaBook.media.status.label)
                .foregroundColor(komgaBook.media.status.color)
            } else {
              if isInProgress {
                Text("\(progress * 100, specifier: "%.0f")%")
                Text("•")
              }
              Text("\(komgaBook.mediaPagesCount) pages")
                .lineLimit(1)
            }
            if komgaBook.downloadStatus != .notDownloaded {
              Spacer()
              Image(systemName: komgaBook.downloadStatus.displayIcon)
                .foregroundColor(komgaBook.downloadStatus.displayColor)
            }
          }
          .font(.caption)
          .foregroundColor(.secondary)
        }.font(.footnote)
      }
    }
    .frame(width: cardWidth)
    .frame(maxHeight: .infinity, alignment: .top)
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
