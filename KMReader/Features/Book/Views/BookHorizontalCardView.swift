//
// BookHorizontalCardView.swift
//
//

import SwiftUI

/// Horizontal book card: cover on the left,
/// title/series/progress on the right, inside a rounded material card.
struct BookHorizontalCardView: View {
  let item: BookDisplayItem
  var coverWidth: CGFloat = 45
  var onReadBook: ((Bool) -> Void)? = nil
  var onMutationCompleted: (() -> Void)? = nil
  var onDeleteRequested: (() -> Void)? = nil
  var showSeriesNavigation: Bool = true

  @AppStorage("thumbnailBlurUnreadCovers") private var thumbnailBlurUnreadCovers: Bool = false
  @State private var showReadListPicker = false
  @State private var showEditSheet = false

  private var titleSize: CGFloat {
    LayoutConfig.horizontalCardFontSize
  }

  private var seriesSize: CGFloat {
    LayoutConfig.horizontalCardSeriesFontSize
  }

  private var metaSize: CGFloat {
    LayoutConfig.horizontalCardMetaFontSize
  }

  private var accessoryIconSize: CGFloat {
    LayoutConfig.horizontalCardAccessoryIconSize
  }

  private var coverBlurRadius: CGFloat {
    thumbnailBlurUnreadCovers && item.isUnread ? CoverBlurStyle.unreadRadius : 0
  }

  private var bookContextMenu: some View {
    BookContextMenu(
      book: item.book,
      downloadStatus: item.downloadStatus,
      onReadBook: onReadBook,
      onShowReadListPicker: {
        #if os(macOS)
          // Present in a standalone window: a view-attached sheet triggered
          // from an NSMenu action can wedge the app on macOS 15.
          PickerWindowOpener.shared.open(.readList(bookId: item.bookId))
        #else
          showReadListPicker = true
        #endif
      },
      onDeleteRequested: onDeleteRequested,
      onEditRequested: {
        showEditSheet = true
      },
      onMutationCompleted: onMutationCompleted,
      showDetailNavigation: true,
      showSeriesNavigation: showSeriesNavigation
    )
  }

  var body: some View {
    // Cover and text form a single button so they highlight together and form
    // one focus target on tvOS; the trailing accessories stay separate
    // targets, like Apple Books' cloud and ellipsis buttons.
    HStack(alignment: .center, spacing: 12) {
      Button {
        onReadBook?(false)
      } label: {
        HStack(alignment: .center, spacing: 12) {
          ThumbnailImage(
            id: item.bookId,
            type: .book,
            shadowStyle: .platform,
            contentBlurRadius: coverBlurRadius,
            width: coverWidth,
            preserveAspectRatioOverride: false
          )
          .frame(width: coverWidth)

          VStack(alignment: .leading, spacing: 0) {
            Spacer(minLength: 0)

            Text(item.bookTitleLine)
              .font(.system(size: titleSize, weight: .semibold))
              .foregroundColor(item.isCompleted ? .secondary : .primary)
              .lineLimit(2)
              .multilineTextAlignment(.leading)
              .padding(.bottom, 4)

            if item.oneshot {
              Text("Oneshot")
                .font(.system(size: seriesSize))
                .foregroundColor(.primary)
                .lineLimit(1)
            } else if !item.seriesTitle.isEmpty {
              Text(item.seriesTitle)
                .font(.system(size: seriesSize))
                .foregroundColor(.primary)
                .lineLimit(1)
            }

            Spacer(minLength: 0)

            bottomBar

            Spacer(minLength: 0)
          }
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
        .contentShape(Rectangle())
      }
      .adaptiveButtonStyle(.plain)

      accessories
    }
    .padding(8)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background {
      RoundedRectangle(cornerRadius: 12)
        .fill(Color.cardBackground)
        .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
    }
    .contentShape(Rectangle())
    #if os(iOS)
      .contentShape(.contextMenuPreview, RoundedRectangle(cornerRadius: 12))
    #endif
    .contextMenu {
      bookContextMenu
    }
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
  private var accessories: some View {
    HStack(spacing: 6) {
      if let icon = item.downloadStatus.displayIcon {
        DownloadStatusIcon(
          systemName: icon,
          spinning: item.downloadStatus.isPending,
          color: .secondary
        )
        .font(.system(size: accessoryIconSize))
      }

      EllipsisMenuButton {
        bookContextMenu
      }
      .font(.system(size: accessoryIconSize, weight: .medium))
    }
    .padding(.trailing, 2)
  }

  @ViewBuilder
  private var bottomBar: some View {
    HStack(spacing: 4) {
      let mediaStatus = item.media.statusValue
      if item.isUnavailable {
        Text("Unavailable")
          .foregroundColor(.red)
      } else if mediaStatus != .ready {
        Text(mediaStatus.label)
          .foregroundColor(mediaStatus.color)
      } else {
        if item.progress > 0 && item.progress < 1 {
          Text(item.progress, format: .percent.precision(.fractionLength(0)))
          Text("•")
        }
        if item.progress == 1 {
          Image(systemName: "checkmark.circle")
            .foregroundColor(.secondary)
            .font(.system(size: metaSize))
        }
        Text(item.progress == 1 ? item.completedMetaText : "\(item.mediaPagesCount) pages")
      }
    }
    .font(.system(size: metaSize))
    .foregroundColor(.secondary)
    .lineLimit(1)
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
