//
//  BookCardView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftData
import SwiftUI

struct BookCardView: View {
  let book: Book
  var viewModel: BookViewModel
  let cardWidth: CGFloat
  var onReadBook: ((Bool) -> Void)? = nil
  var onBookUpdated: (() -> Void)? = nil
  var showSeriesTitle: Bool = false
  var showSeriesNavigation: Bool = true

  // SwiftData query for reactive download status
  @Query private var komgaBooks: [KomgaBook]

  @AppStorage("showBookCardSeriesTitle") private var showBookCardSeriesTitle: Bool = true
  @State private var showReadListPicker = false
  @State private var showDeleteConfirmation = false
  @State private var showEditSheet = false

  init(
    book: Book,
    viewModel: BookViewModel,
    cardWidth: CGFloat,
    onReadBook: ((Bool) -> Void)? = nil,
    onBookUpdated: (() -> Void)? = nil,
    showSeriesTitle: Bool = false,
    showSeriesNavigation: Bool = true
  ) {
    self.book = book
    self.viewModel = viewModel
    self.cardWidth = cardWidth
    self.onReadBook = onReadBook
    self.onBookUpdated = onBookUpdated
    self.showSeriesTitle = showSeriesTitle
    self.showSeriesNavigation = showSeriesNavigation

    let instanceId = AppConfig.currentInstanceId
    let compositeId = "\(instanceId)_\(book.id)"
    _komgaBooks = Query(filter: #Predicate<KomgaBook> { $0.id == compositeId })
  }

  private var progress: Double {
    guard let readProgress = book.readProgress else { return 0 }
    guard book.media.pagesCount > 0 else { return 0 }
    return Double(readProgress.page) / Double(book.media.pagesCount)
  }

  private var isInProgress: Bool {
    guard let readProgress = book.readProgress else { return false }
    return !readProgress.completed
  }

  var shouldShowSeriesTitle: Bool {
    showSeriesTitle && showBookCardSeriesTitle && !book.seriesTitle.isEmpty
  }

  var bookTitleLineLimit: Int {
    shouldShowSeriesTitle ? 1 : 2
  }

  var body: some View {
    Button {
      onReadBook?(false)
    } label: {
      VStack(alignment: .leading, spacing: 6) {
        ThumbnailImage(id: book.id, type: .book, width: cardWidth) {
          ZStack {
            if let readProgress = book.readProgress {
              if !readProgress.completed {
                ThumbnailOverlayGradient(position: .bottom)
                ReadingProgressBar(progress: progress)
                  .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
              } else {
                EmptyView()
              }
            } else {
              UnreadIndicator()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            }
          }
        }

        VStack(alignment: .leading, spacing: 2) {
          if shouldShowSeriesTitle {
            Text(book.seriesTitle)
              .font(.caption)
              .foregroundColor(.secondary)
              .lineLimit(1)
          }
          Text("\(book.metadata.number) - \(book.metadata.title)")
            .font(.caption)
            .foregroundColor(.primary)
            .lineLimit(bookTitleLineLimit)

          Group {
            if book.deleted {
              Text("Unavailable")
                .foregroundColor(.red)
            } else {
              HStack(spacing: 4) {
                Text("\(book.media.pagesCount) pages")
                  + Text(" • \(book.size)")
                  .font(.footnote)
                if book.oneshot {
                  Text("•")
                  Text("Oneshot")
                    .foregroundColor(.blue)
                }
              }
              .foregroundColor(.secondary)
              .lineLimit(1)
            }
          }.font(.caption2)
        }
        .frame(width: cardWidth, alignment: .leading)
      }
      .frame(maxHeight: .infinity, alignment: .top)
      .contentShape(Rectangle())
    }
    .adaptiveButtonStyle(.plain)
    .contextMenu {
      if let komgaBook = komgaBooks.first {
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
    .sheet(isPresented: $showEditSheet) {
      BookEditSheet(book: book)
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
          bookIds: [book.id]
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
        try await BookService.shared.deleteBook(bookId: book.id)
        await CacheManager.clearCache(forBookId: book.id)
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
