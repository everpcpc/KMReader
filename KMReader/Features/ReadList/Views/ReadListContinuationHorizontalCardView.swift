//
// ReadListContinuationHorizontalCardView.swift
//
//

import SwiftUI

/// Horizontal card for a read list the user is reading: the next book's cover,
/// the read list's name, and how far along the list is. Opens the next book in
/// the read list's order. Tinted by the next book's cover, like the Keep
/// Reading card it sits next to.
@MainActor
struct ReadListContinuationHorizontalCardView: View {
  let continuation: ReadListContinuation
  var coverWidth: CGFloat = 80

  @AppStorage("currentAccount") private var current: Current = .init()
  @Environment(\.readerActions) private var readerActions
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

  var body: some View {
    Button {
      readerActions.open(continuation: continuation)
    } label: {
      HStack(alignment: .center, spacing: 10) {
        ThumbnailImage(
          id: continuation.bookId,
          type: .book,
          shadowStyle: .platform,
          width: coverWidth,
          preserveAspectRatioOverride: false
        )
        .frame(width: coverWidth)
        .allowsHitTesting(false)

        VStack(alignment: .leading, spacing: 0) {
          Spacer(minLength: 0)

          Text(continuation.readListName)
            .font(.system(LayoutConfig.horizontalCardTitleTextStyle, weight: .medium))
            .foregroundColor(primaryTextColor)
            .lineLimit(2)
            .multilineTextAlignment(.leading)

          Spacer(minLength: 0)

          VStack(alignment: .leading, spacing: 4) {
            Text(continuation.bookTitle)
              .lineLimit(1)

            HStack(spacing: 4) {
              ReadListContinuationProgressText(continuation: continuation)
              if let icon = continuation.downloadStatus.displayIcon {
                Spacer()
                DownloadStatusIcon(
                  systemName: icon,
                  spinning: continuation.downloadStatus.isPending,
                  color: secondaryTextColor
                )
                .font(.system(LayoutConfig.horizontalCardTertiaryTextStyle))
              }
            }
            .lineLimit(1)
          }
          .font(.system(LayoutConfig.horizontalCardSecondaryTextStyle))
          .foregroundColor(secondaryTextColor)
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
      ReadListContinuationContextMenu(continuation: continuation)
    }
    .coverArtwork(instanceId: current.instanceId, bookId: continuation.bookId, into: $coverArtwork)
  }
}
