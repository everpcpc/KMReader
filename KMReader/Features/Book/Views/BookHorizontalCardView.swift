//
// BookHorizontalCardView.swift
//
//

import SwiftUI

/// Horizontal book card: cover on the left,
/// series/title/progress on the right, inside a rounded material card.
struct BookHorizontalCardView: View {
  let item: BookDisplayItem
  var coverWidth: CGFloat = 60
  var onReadBook: ((Bool) -> Void)? = nil
  var onMutationCompleted: (() -> Void)? = nil
  var onDeleteRequested: (() -> Void)? = nil
  var showSeriesNavigation: Bool = true

  @AppStorage("thumbnailBlurUnreadCovers") private var thumbnailBlurUnreadCovers: Bool = false
  @State private var showReadListPicker = false
  @State private var showEditSheet = false
  @State private var coverArtwork: PlatformImage?

  private var isCoverTinted: Bool {
    coverArtwork != nil
  }

  private var primaryTextColor: Color {
    isCoverTinted ? .white : .primary
  }

  private var secondaryTextColor: Color {
    isCoverTinted ? .white.opacity(0.65) : .secondary
  }

  private var textSize: CGFloat {
    LayoutConfig.horizontalCardFontSize
  }

  private var iconSize: CGFloat {
    LayoutConfig.horizontalCardIconSize
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
    // The whole card is a single button so cover and text highlight together
    // and form one focus target on tvOS.
    Button {
      onReadBook?(false)
    } label: {
      HStack(alignment: .center, spacing: 10) {
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

          if item.oneshot {
            Text("Oneshot")
              .font(.system(size: textSize))
              .foregroundColor(primaryTextColor)
              .lineLimit(1)
              .padding(.bottom, 4)
          } else if !item.seriesTitle.isEmpty {
            Text(item.seriesTitle)
              .font(.system(size: textSize))
              .foregroundColor(primaryTextColor)
              .lineLimit(1)
              .padding(.bottom, 4)
          }

          Text(item.bookTitleLine)
            .font(.system(size: textSize, weight: .bold))
            .foregroundColor(item.isCompleted ? secondaryTextColor : primaryTextColor)
            .lineLimit(2)
            .multilineTextAlignment(.leading)

          Spacer(minLength: 0)

          bottomBar

          Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
      }
      .padding(6)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background {
        CoverTintedCardBackground(artwork: coverArtwork)
      }
      .contentShape(Rectangle())
      #if os(iOS)
        .contentShape(.contextMenuPreview, RoundedRectangle(cornerRadius: 12))
      #endif
    }
    .adaptiveButtonStyle(.plain)
    .contextMenu {
      bookContextMenu
    }
    .coverArtwork(instanceId: item.instanceId, bookId: item.bookId, into: $coverArtwork)
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
            .foregroundColor(secondaryTextColor)
            .font(.system(size: iconSize))
        }
        Text(item.progress == 1 ? item.completedMetaText : "\(item.mediaPagesCount) pages")
      }
      if let icon = item.downloadStatus.displayIcon {
        Spacer()
        DownloadStatusIcon(
          systemName: icon, spinning: item.downloadStatus.isPending, color: secondaryTextColor
        )
        .font(.system(size: iconSize))
      }
    }
    .font(.system(size: textSize))
    .foregroundColor(secondaryTextColor)
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
