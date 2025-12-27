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
  @Environment(\.readerZoomNamespace) private var zoomNamespace
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

  var pagesText: String {
    String(localized: "\(komgaBook.mediaPagesCount) pages")
  }

  var body: some View {
    VStack(alignment: .leading) {
      Button {
        onReadBook?(false)
      } label: {
        ThumbnailImage(id: komgaBook.bookId, type: .book, width: cardWidth, alignment: .bottom) {
          ZStack {
            if let progressCompleted = komgaBook.progressCompleted {
              if !progressCompleted {
                ThumbnailOverlayGradient(position: .bottom)
                ReadingProgressBar(progress: progress)
                  .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
              }
            } else {
              UnreadIndicator()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            }
          }
        }
        .adaptiveButtonStyle(.plain)
        .ifLet(zoomNamespace) { view, namespace in
          view.matchedTransitionSourceIfAvailable(id: komgaBook.bookId, in: namespace)
        }
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
            if komgaBook.deleted {
              Text("Unavailable")
                .foregroundColor(.red)
            } else {
              Text("\(pagesText) • \(komgaBook.size)")
                .lineLimit(1)
            }
            Spacer()
            if komgaBook.downloadStatus != .notDownloaded {
              Image(systemName: komgaBook.downloadStatus.displayIcon)
                .foregroundColor(komgaBook.downloadStatus.displayColor)
            }
            Menu {
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
            } label: {
              HStack {
                Image(systemName: "ellipsis")
              }
              .foregroundColor(.secondary)
              .contentShape(Rectangle())
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
