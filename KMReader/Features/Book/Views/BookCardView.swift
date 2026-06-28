//
// BookCardView.swift
//
//

import SwiftUI

struct BookCardView: View {
  let item: BookDisplayItem
  var onReadBook: ((Bool) -> Void)? = nil
  var onMutationCompleted: (() -> Void)? = nil
  var onDeleteRequested: (() -> Void)? = nil
  var showSeriesTitle: Bool = false
  var showSeriesNavigation: Bool = true

  @AppStorage("showBookCardSeriesTitle") private var showBookCardSeriesTitle: Bool = true
  @AppStorage("coverOnlyCards") private var coverOnlyCards: Bool = false
  @AppStorage("cardTextOverlayMode") private var cardTextOverlayMode: Bool = false
  @AppStorage("thumbnailShowUnreadIndicator") private var thumbnailShowUnreadIndicator: Bool = true
  @AppStorage("thumbnailShowProgressBar") private var thumbnailShowProgressBar: Bool = true
  @AppStorage("thumbnailBlurUnreadCovers") private var thumbnailBlurUnreadCovers: Bool = false
  @State private var showReadListPicker = false
  @State private var showEditSheet = false

  private var progress: Double {
    guard let progressPage = item.progressPage else { return 0 }
    guard item.mediaPagesCount > 0 else { return 0 }
    return Double(progressPage) / Double(item.mediaPagesCount)
  }

  var shouldShowSeriesTitle: Bool {
    return showSeriesTitle && showBookCardSeriesTitle && !item.seriesTitle.isEmpty
  }

  var bookTitleLine: String {
    if item.oneshot {
      return item.metaTitle
    }
    return String("\(item.metaNumber) - \(item.metaTitle)")
  }

  var bookTitleLineLimit: Int {
    (shouldShowSeriesTitle || item.oneshot) ? 1 : 2
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

  private var coverBlurRadius: CGFloat {
    thumbnailBlurUnreadCovers && item.isUnread ? CoverBlurStyle.unreadRadius : 0
  }

  private var completedMetaText: String {
    item.completedLastReadText ?? "\(item.mediaPagesCount) pages"
  }

  var body: some View {
    VStack(alignment: .leading, spacing: contentSpacing) {
      ThumbnailImage(
        id: item.bookId,
        type: .book,
        shadowStyle: .platform,
        contentBlurRadius: coverBlurRadius,
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

          if item.isUnread && thumbnailShowUnreadIndicator {
            UnreadIndicator()
              .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
          }
        }
      } menu: {
        BookContextMenu(
          book: item.book,
          downloadStatus: item.downloadStatus,
          onReadBook: onReadBook,
          onShowReadListPicker: {
            showReadListPicker = true
          },
          onDeleteRequested: onDeleteRequested,
          onEditRequested: {
            showEditSheet = true
          },
          onMutationCompleted: onMutationCompleted,
          showSeriesNavigation: showSeriesNavigation
        )
      }

      if thumbnailShowProgressBar && !cardTextOverlayMode {
        ReadingProgressBar(progress: progress, type: .card)
          .opacity(item.isInProgress ? 1 : 0)
      }

      if !cardTextOverlayMode && !coverOnlyCards {
        VStack(alignment: .leading) {
          if item.oneshot {
            Text("Oneshot")
              .font(.caption)
              .foregroundColor(.blue)
              .lineLimit(1)
          } else if shouldShowSeriesTitle {
            Text(item.seriesTitle)
              .font(.caption)
              .foregroundColor(.secondary)
              .lineLimit(1)
          }

          Text(bookTitleLine)
            .lineLimit(bookTitleLineLimit)

          HStack(spacing: 4) {
            let mediaStatus = item.media.statusValue
            if item.isUnavailable {
              Text("Unavailable")
                .foregroundColor(.red)
            } else if mediaStatus != .ready {
              Text(mediaStatus.label)
                .foregroundColor(mediaStatus.color)
            } else {
              if progress > 0 && progress < 1 {
                Text(progress, format: .percent.precision(.fractionLength(0)))
                Text("•")
              }
              if progress == 1 {
                Image(systemName: "checkmark.circle.fill")
                  .foregroundColor(.secondary)
                  .font(.caption2)
              }
              Text(progress == 1 ? completedMetaText : "\(item.mediaPagesCount) pages")
                .lineLimit(1)
            }
            if item.downloadStatus != .notDownloaded {
              Spacer()
              Image(systemName: item.downloadStatus.displayIcon)
                .foregroundColor(item.downloadStatus.displayColor)
                .font(.caption2)
            }
          }
          .font(.caption)
          .foregroundColor(.secondary)
        }.font(.footnote)
      }
    }
    .frame(maxHeight: .infinity, alignment: .top)
    .sheet(isPresented: $showReadListPicker) {
      ReadListPickerSheet(
        bookId: item.bookId,
        onSelect: { readListId in
          addToReadList(readListId: readListId)
        }
      )
    }
    .sheet(isPresented: $showEditSheet) {
      BookEditSheet(book: item.book)
    }

  }

  @ViewBuilder
  private var overlayTextContent: some View {
    let style = CardOverlayTextStyle.standard
    let showDownloadIcon = item.downloadStatus != .notDownloaded
    let showProgressBar = item.isInProgress && thumbnailShowProgressBar

    CardOverlayTextStack(
      title: bookTitleLine,
      subtitle: (shouldShowSeriesTitle && !item.oneshot) ? item.seriesTitle : nil,
      titleLineLimit: bookTitleLineLimit,
      style: style
    ) {
      HStack(spacing: 4) {
        let mediaStatus = item.media.statusValue
        if item.isUnavailable {
          Text("Unavailable")
            .foregroundColor(.red)
        } else if mediaStatus != .ready {
          Text(mediaStatus.label)
            .foregroundColor(mediaStatus.color)
        } else {
          if progress > 0 && progress < 1 {
            Text(progress, format: .percent.precision(.fractionLength(0)))
            Text("•")
          }
          if progress == 1 {
            Image(systemName: "checkmark.circle.fill")
              .foregroundColor(style.secondaryColor)
              .font(.caption2)
          }
          Text(progress == 1 ? completedMetaText : "\(item.mediaPagesCount) pages")
            .lineLimit(1)
        }
        if showDownloadIcon && !showProgressBar {
          Spacer()
          Image(systemName: item.downloadStatus.displayIcon)
            .foregroundColor(item.downloadStatus.displayColor)
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
            Image(systemName: item.downloadStatus.displayIcon)
              .foregroundColor(item.downloadStatus.displayColor)
              .font(.caption2)
          }
        }
      }
    }
  }

  private func addToReadList(readListId: String) {
    Task {
      do {
        try await ReadListService.addBooksToReadList(
          readListId: readListId,
          bookIds: [item.bookId]
        )
        ErrorManager.shared.notify(
          message: String(localized: "notification.book.booksAddedToReadList"))
        onMutationCompleted?()
      } catch {
        ErrorManager.shared.alert(error: error)
      }
    }
  }

}
