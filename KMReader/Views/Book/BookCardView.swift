//
//  BookCardView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct BookCardView: View {
  let book: Book
  var viewModel: BookViewModel
  let cardWidth: CGFloat
  var onBookUpdated: (() -> Void)? = nil
  var showSeriesTitle: Bool = false

  @AppStorage("showBookCardSeriesTitle") private var showBookCardSeriesTitle: Bool = true
  @Environment(ReaderPresentationManager.self) private var readerPresentation
  @State private var showReadListPicker = false
  @State private var showDeleteConfirmation = false
  @State private var showEditSheet = false
  @State private var showDownloadSheet = false

  private var thumbnailURL: URL? {
    BookService.shared.getBookThumbnailURL(id: book.id)
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
      presentReader(incognito: false)
    } label: {
      VStack(alignment: .leading, spacing: 6) {
        ThumbnailImage(url: thumbnailURL, width: cardWidth) {
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
                Text("\(book.media.pagesCount) pages · \(book.size)")
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
      BookContextMenu(
        book: book,
        viewModel: viewModel,
        onReadBook: { incognito in
          presentReader(incognito: incognito)
        },
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
        onDownloadRequested: {
          showDownloadSheet = true
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
    .sheet(isPresented: $showEditSheet) {
      BookEditSheet(book: book)
        .onDisappear {
          onBookUpdated?()
        }
    }
    .sheet(isPresented: $showDownloadSheet) {
      BookDownloadSheet(book: book)
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
        await CacheManager.clearCache(forBookId: book.id)
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

  private func presentReader(incognito: Bool) {
    readerPresentation.present(
      book: book,
      incognito: incognito,
      onDismiss: onBookUpdated
    )
  }
}
