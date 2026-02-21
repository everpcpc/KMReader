//
// BookCardView.swift
//
//

import SwiftUI

struct BookCardView: View {
  let book: Book
  let downloadStatus: DownloadStatus
  var onReadBook: ((Bool) -> Void)? = nil
  var showSeriesTitle: Bool = false
  var showSeriesNavigation: Bool = true

  @AppStorage("showBookCardSeriesTitle") private var showBookCardSeriesTitle: Bool = true
  @AppStorage("coverOnlyCards") private var coverOnlyCards: Bool = false
  @AppStorage("cardTextOverlayMode") private var cardTextOverlayMode: Bool = false
  @AppStorage("thumbnailShowUnreadIndicator") private var thumbnailShowUnreadIndicator: Bool = true
  @AppStorage("thumbnailShowProgressBar") private var thumbnailShowProgressBar: Bool = true
  @State private var showReadListPicker = false
  @State private var showDeleteConfirmation = false
  @State private var showEditSheet = false

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
    return showSeriesTitle && showBookCardSeriesTitle && !book.seriesTitle.isEmpty
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

  var contentSpacing: CGFloat {
    if cardTextOverlayMode {
      return 0
    }
    if thumbnailShowProgressBar {
      return 2
    }
    return 12
  }

  var body: some View {
    VStack(alignment: .leading, spacing: contentSpacing) {
      ThumbnailImage(
        id: book.id,
        type: .book,
        shadowStyle: .platform,
        alignment: .bottom,
        preserveAspectRatioOverride: cardTextOverlayMode ? false : nil,
        onAction: { onReadBook?(false) }
      ) {
        ZStack {
          if cardTextOverlayMode {
            CardTextOverlay(cornerRadius: 8) {
              overlayTextContent
            }
          }

          if book.readProgress == nil && thumbnailShowUnreadIndicator {
            UnreadIndicator()
              .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
          }
        }
      } menu: {
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
      }

      if thumbnailShowProgressBar && !cardTextOverlayMode {
        ReadingProgressBar(progress: progress, type: .card)
          .opacity(isInProgress ? 1 : 0)
      }

      if !cardTextOverlayMode && !coverOnlyCards {
        VStack(alignment: .leading) {
          if book.oneshot {
            Text("Oneshot")
              .font(.caption)
              .foregroundColor(.blue)
              .lineLimit(1)
          } else if shouldShowSeriesTitle {
            Text(book.seriesTitle)
              .font(.caption)
              .foregroundColor(.secondary)
              .lineLimit(1)
          }

          Text(bookTitleLine)
            .lineLimit(bookTitleLineLimit)

          HStack(spacing: 4) {
            if book.deleted {
              Text("Unavailable")
                .foregroundColor(.red)
            } else if book.media.status != .ready {
              Text(book.media.status.label)
                .foregroundColor(book.media.status.color)
            } else {
              if progress > 0 && progress < 1 {
                Text("\(progress * 100, specifier: "%.0f")%")
                Text("•")
              }
              if progress == 1 {
                Image(systemName: "checkmark.circle.fill")
                  .foregroundColor(.secondary)
                  .font(.caption2)
              }
              Text("\(book.media.pagesCount) pages")
                .lineLimit(1)
            }
            if downloadStatus != .notDownloaded {
              Spacer()
              Image(systemName: downloadStatus.displayIcon)
                .foregroundColor(downloadStatus.displayColor)
                .font(.caption2)
            }
          }
          .font(.caption)
          .foregroundColor(.secondary)
        }.font(.footnote)
      }
    }
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

  @ViewBuilder
  private var overlayTextContent: some View {
    let style = CardOverlayTextStyle.standard
    let showDownloadIcon = downloadStatus != .notDownloaded
    let showProgressBar = isInProgress && thumbnailShowProgressBar

    CardOverlayTextStack(
      title: bookTitleLine,
      subtitle: (shouldShowSeriesTitle && !book.oneshot) ? book.seriesTitle : nil,
      titleLineLimit: bookTitleLineLimit,
      style: style
    ) {
      HStack(spacing: 4) {
        if book.deleted {
          Text("Unavailable")
            .foregroundColor(.red)
        } else if book.media.status != .ready {
          Text(book.media.status.label)
            .foregroundColor(book.media.status.color)
        } else {
          if progress > 0 && progress < 1 {
            Text("\(progress * 100, specifier: "%.0f")%")
            Text("•")
          }
          if progress == 1 {
            Image(systemName: "checkmark.circle.fill")
              .foregroundColor(style.secondaryColor)
              .font(.caption2)
          }
          Text("\(book.media.pagesCount) pages")
            .lineLimit(1)
        }
        if showDownloadIcon && !showProgressBar {
          Spacer()
          Image(systemName: downloadStatus.displayIcon)
            .foregroundColor(downloadStatus.displayColor)
            .font(.caption2)
        }
      }
    } progress: {
      if showProgressBar {
        HStack(spacing: 6) {
          ReadingProgressBar(progress: progress, type: .card)
            .padding(.top, 2)
            .layoutPriority(1)
          if showDownloadIcon {
            Image(systemName: downloadStatus.displayIcon)
              .foregroundColor(downloadStatus.displayColor)
              .font(.caption2)
          }
        }
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
