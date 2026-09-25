//
// ReadListContinuationCardView.swift
//
//

import SwiftUI

/// Large or small card for a read list the user is reading, laid out like a
/// book card: the next book's cover and progress bar, then the read list's
/// name, the book's title, and how far along the list is. Opens the next book
/// in the read list's order.
struct ReadListContinuationCardView: View {
  let continuation: ReadListContinuation
  /// Small dashboard cards are cover-only: at that width every text line
  /// truncates and stops carrying information.
  var coverOnly: Bool = false
  /// Text styles scale with this width.
  var cardWidth: CGFloat = LayoutConfig.gridCardWidth

  @AppStorage("coverOnlyCards") private var coverOnlyCards: Bool = false
  @AppStorage("cardTextOverlayMode") private var cardTextOverlayMode: Bool = false
  @AppStorage("thumbnailShowProgressBar") private var thumbnailShowProgressBar: Bool = true
  @AppStorage("thumbnailBlurUnreadCovers") private var thumbnailBlurUnreadCovers: Bool = false
  @Environment(\.readerActions) private var readerActions

  /// The book a list continues with is in progress or unread; only a book in
  /// progress has progress.
  private var isInProgress: Bool {
    continuation.bookProgress != nil
  }

  /// Cover-only cards never render the text overlay, even in overlay mode.
  private var showsTextOverlay: Bool {
    cardTextOverlayMode && !coverOnly
  }

  private var contentSpacing: CGFloat {
    if showsTextOverlay {
      return 0
    }
    if thumbnailShowProgressBar {
      return 2
    }
    return 12
  }

  private var coverBlurRadius: CGFloat {
    thumbnailBlurUnreadCovers && !isInProgress ? CoverBlurStyle.unreadRadius : 0
  }

  private var titleTextStyle: Font.TextStyle {
    LayoutConfig.cardTitleTextStyle(cardWidth: cardWidth)
  }

  private var secondaryTextStyle: Font.TextStyle {
    LayoutConfig.cardSecondaryTextStyle(cardWidth: cardWidth)
  }

  private var tertiaryTextStyle: Font.TextStyle {
    LayoutConfig.cardTertiaryTextStyle(cardWidth: cardWidth)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: contentSpacing) {
      ThumbnailImage(
        id: continuation.bookId,
        type: .book,
        shadowStyle: .platform,
        contentBlurRadius: coverBlurRadius,
        alignment: .bottom,
        preserveAspectRatioOverride: showsTextOverlay ? false : nil,
        onAction: { readerActions.open(continuation: continuation) }
      ) {
        if showsTextOverlay {
          CardTextOverlay(cornerRadius: 8) {
            overlayTextContent
          }
        }
      } menu: {
        ReadListContinuationContextMenu(continuation: continuation)
      }

      if thumbnailShowProgressBar && !showsTextOverlay {
        ReadingProgressBar(progress: continuation.bookProgress ?? 0, type: .card)
          .opacity(isInProgress ? 1 : 0)
      }

      if !showsTextOverlay && !coverOnlyCards && !coverOnly {
        VStack(alignment: .leading) {
          Text(continuation.readListName)
            .font(.system(secondaryTextStyle))
            .foregroundColor(.secondary)
            .lineLimit(1)

          Text(continuation.bookTitle)
            .lineLimit(1)

          HStack(spacing: 4) {
            ReadListContinuationProgressText(continuation: continuation)
              .lineLimit(1)
            if let icon = continuation.downloadStatus.displayIcon {
              Spacer()
              DownloadStatusIcon(systemName: icon, spinning: continuation.downloadStatus.isPending)
                .font(.system(tertiaryTextStyle))
            }
          }
          .font(.system(secondaryTextStyle))
          .foregroundColor(.secondary)
        }
        .font(.system(titleTextStyle))
      }
    }
    .frame(maxHeight: .infinity, alignment: .top)
  }

  @ViewBuilder
  private var overlayTextContent: some View {
    let style = CardOverlayTextStyle.standard
    let downloadIcon = continuation.downloadStatus.displayIcon
    let showProgressBar = isInProgress && thumbnailShowProgressBar

    CardOverlayTextStack(
      title: continuation.bookTitle,
      subtitle: continuation.readListName,
      style: style
    ) {
      HStack(spacing: 4) {
        ReadListContinuationProgressText(continuation: continuation)
          .lineLimit(1)
        if let icon = downloadIcon, !showProgressBar {
          Spacer()
          DownloadStatusIcon(
            systemName: icon, spinning: continuation.downloadStatus.isPending,
            color: style.secondaryColor
          )
          .font(.caption2)
        }
      }
    } progress: {
      if showProgressBar {
        HStack(spacing: 6) {
          ReadingProgressBar(progress: continuation.bookProgress ?? 0, type: .card)
            .padding(.top, 2)
            .layoutPriority(1)
          if let icon = downloadIcon {
            DownloadStatusIcon(
              systemName: icon, spinning: continuation.downloadStatus.isPending,
              color: style.secondaryColor
            )
            .font(.caption2)
          }
        }
      }
    }
  }
}
