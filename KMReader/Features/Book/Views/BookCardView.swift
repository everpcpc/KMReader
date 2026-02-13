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

  var padding: CGFloat {
    if cardTextOverlayMode {
      return 0
    }
    if isInProgress && thumbnailShowProgressBar {
      return 4
    }
    return 12
  }

  var body: some View {
    VStack(alignment: .leading, spacing: padding) {
      ThumbnailImage(
        id: komgaBook.bookId,
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

          if komgaBook.progressCompleted == nil && thumbnailShowUnreadIndicator {
            UnreadIndicator()
              .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
          }
        }
      } menu: {
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
      }

      if isInProgress && thumbnailShowProgressBar && !cardTextOverlayMode {
        ReadingProgressBar(progress: progress, type: .card)
      }

      if !cardTextOverlayMode && !coverOnlyCards {
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
              if progress > 0 && progress < 1 {
                Text("\(progress * 100, specifier: "%.0f")%")
                Text("•")
              }
              if progress == 1 {
                Image(systemName: "checkmark.circle.fill")
                  .foregroundColor(.secondary)
                  .font(.caption2)
              }
              Text("\(komgaBook.mediaPagesCount) pages")
                .lineLimit(1)
            }
            if komgaBook.downloadStatus != .notDownloaded {
              Spacer()
              Image(systemName: komgaBook.downloadStatus.displayIcon)
                .foregroundColor(komgaBook.downloadStatus.displayColor)
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

  @ViewBuilder
  private var overlayTextContent: some View {
    let style = CardOverlayTextStyle.standard
    let showDownloadIcon = komgaBook.downloadStatus != .notDownloaded
    let showProgressBar = isInProgress && thumbnailShowProgressBar

    CardOverlayTextStack(
      title: bookTitleLine,
      subtitle: (shouldShowSeriesTitle && !komgaBook.oneshot) ? komgaBook.seriesTitle : nil,
      titleLineLimit: bookTitleLineLimit,
      style: style
    ) {
      HStack(spacing: 4) {
        if komgaBook.isUnavailable {
          Text("Unavailable")
            .foregroundColor(.red)
        } else if komgaBook.media.status != .ready {
          Text(komgaBook.media.status.label)
            .foregroundColor(komgaBook.media.status.color)
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
          Text("\(komgaBook.mediaPagesCount) pages")
            .lineLimit(1)
        }
        if showDownloadIcon && !showProgressBar {
          Spacer()
          Image(systemName: komgaBook.downloadStatus.displayIcon)
            .foregroundColor(komgaBook.downloadStatus.displayColor)
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
            Image(systemName: komgaBook.downloadStatus.displayIcon)
              .foregroundColor(komgaBook.downloadStatus.displayColor)
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
