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
  var viewModel: BookViewModel
  let cardWidth: CGFloat
  var onReadBook: ((Bool) -> Void)? = nil
  var onBookUpdated: (() -> Void)? = nil
  var showSeriesTitle: Bool = false
  var showSeriesNavigation: Bool = true

  @AppStorage("showBookCardSeriesTitle") private var showBookCardSeriesTitle: Bool = true
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
    showSeriesTitle && showBookCardSeriesTitle && !komgaBook.seriesTitle.isEmpty
  }

  var bookTitleLineLimit: Int {
    shouldShowSeriesTitle ? 1 : 2
  }

  var body: some View {
    Button {
      onReadBook?(false)
    } label: {
      VStack(alignment: .leading, spacing: 6) {
        ThumbnailImage(id: komgaBook.bookId, type: .book, width: cardWidth) {
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
        .ifLet(zoomNamespace) { view, namespace in
          view.matchedTransitionSourceIfAvailable(id: komgaBook.bookId, in: namespace)
        }

        VStack(alignment: .leading, spacing: 2) {
          if shouldShowSeriesTitle {
            Text(komgaBook.seriesTitle)
              .font(.caption)
              .foregroundColor(.secondary)
              .lineLimit(1)
          }
          Text("\(komgaBook.metaNumber) - \(komgaBook.metaTitle)")
            .font(.caption)
            .foregroundColor(.primary)
            .lineLimit(bookTitleLineLimit)

          Group {
            if komgaBook.deleted {
              Text("Unavailable")
                .foregroundColor(.red)
            } else {
              HStack(spacing: 4) {
                Text("\(komgaBook.mediaPagesCount) pages")
                  + Text(" • \(komgaBook.size)")
                  .font(.footnote)
                if komgaBook.oneshot {
                  Text("•")
                  Text("Oneshot")
                    .foregroundColor(.blue)
                }
                if komgaBook.downloadStatus != .notDownloaded {
                  Image(systemName: komgaBook.downloadStatus.displayIcon)
                    .foregroundColor(komgaBook.downloadStatus.displayColor)
                    .frame(width: PlatformHelper.iconSize, height: PlatformHelper.iconSize)
                    .padding(.leading, 8)
                }
              }
              .foregroundColor(.secondary)
              .lineLimit(1)
            }
          }.font(.caption2)
        }
      }
      .frame(width: cardWidth, alignment: .leading)
    }
    .adaptiveButtonStyle(.plain)
    .frame(maxHeight: .infinity, alignment: .top)
    .contentShape(Rectangle())
    .contextMenu {
      BookContextMenu(
        komgaBook: komgaBook,
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
