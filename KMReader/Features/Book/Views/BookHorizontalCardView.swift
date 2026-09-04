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

  @AppStorage("thumbnailShowUnreadIndicator") private var thumbnailShowUnreadIndicator: Bool = true
  @AppStorage("thumbnailBlurUnreadCovers") private var thumbnailBlurUnreadCovers: Bool = false
  @AppStorage("gridDensity") private var gridDensity: Double = GridDensity.standard.rawValue
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

  /// Compact density shows the title on a single line so the card height can
  /// actually shrink with the cover instead of being held up by reserved text space.
  private var titleLineLimit: Int {
    gridDensity < GridDensity.standard.rawValue ? 1 : 2
  }

  private var titleTextStyle: Font.TextStyle {
    LayoutConfig.horizontalCardTitleTextStyle(for: gridDensity)
  }

  private var secondaryTextStyle: Font.TextStyle {
    LayoutConfig.horizontalCardSecondaryTextStyle(for: gridDensity)
  }

  private var tertiaryTextStyle: Font.TextStyle {
    LayoutConfig.horizontalCardTertiaryTextStyle(for: gridDensity)
  }

  private var progress: Double {
    guard let progressPage = item.progressPage else { return 0 }
    guard item.mediaPagesCount > 0 else { return 0 }
    return Double(progressPage) / Double(item.mediaPagesCount)
  }

  var bookTitleLine: String {
    if item.oneshot {
      return item.metaTitle
    }
    return String("\(item.metaNumber) - \(item.metaTitle)")
  }

  private var coverBlurRadius: CGFloat {
    thumbnailBlurUnreadCovers && item.isUnread ? CoverBlurStyle.unreadRadius : 0
  }

  private var completedMetaText: String {
    item.completedLastReadText ?? "\(item.mediaPagesCount) pages"
  }

  private var bookContextMenu: some View {
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

  var body: some View {
    // The whole card is a single button so cover and text highlight together
    // and form one focus target on tvOS.
    Button {
      onReadBook?(false)
    } label: {
      HStack(alignment: .top, spacing: 10) {
        ThumbnailImage(
          id: item.bookId,
          type: .book,
          shadowStyle: .platform,
          contentBlurRadius: coverBlurRadius,
          width: coverWidth,
          preserveAspectRatioOverride: false
        ) {
          if item.isUnread && thumbnailShowUnreadIndicator {
            UnreadIndicator()
              .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
          }
        }
        .frame(width: coverWidth)

        VStack(alignment: .leading, spacing: 2) {
          if item.oneshot {
            Text("Oneshot")
              .font(.system(secondaryTextStyle))
              .foregroundColor(isCoverTinted ? secondaryTextColor : .blue)
              .lineLimit(1)
          } else if !item.seriesTitle.isEmpty {
            Text(item.seriesTitle)
              .font(.system(secondaryTextStyle))
              .foregroundColor(secondaryTextColor)
              .lineLimit(1)
          }

          Text(bookTitleLine)
            .font(.system(titleTextStyle))
            .foregroundColor(item.isCompleted ? secondaryTextColor : primaryTextColor)
            .lineLimit(titleLineLimit, reservesSpace: true)
            .multilineTextAlignment(.leading)

          Spacer(minLength: 2)

          bottomBar
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
      }
      .padding(8)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .adaptiveButtonStyle(.plain)
    .background {
      RoundedRectangle(cornerRadius: 12)
        .fill(.regularMaterial)
        .overlay {
          // Overlay content never contributes to layout size, so the flexible
          // blurred image can neither inflate the card nor bleed past it.
          if let coverArtwork {
            Image(platformImage: coverArtwork)
              .resizable()
              .scaledToFill()
              .blur(radius: 28)
              .overlay(Color.black.opacity(0.5))
              .transition(.opacity)
          }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
        .animation(.easeInOut(duration: 0.2), value: isCoverTinted)
    }
    .contentShape(Rectangle())
    #if os(iOS)
      .contentShape(.contextMenuPreview, RoundedRectangle(cornerRadius: 12))
    #endif
    .contextMenu {
      bookContextMenu
    }
    .task(id: item.bookId) {
      coverArtwork = await CoverBackgroundProvider.shared.backgroundImage(
        instanceId: item.instanceId, id: item.bookId, type: .book)
    }
    .onReceive(NotificationCenter.default.publisher(for: .thumbnailDidRefresh)) { notification in
      guard let userInfo = notification.userInfo,
        let id = userInfo["id"] as? String,
        let type = userInfo["type"] as? String,
        id == item.bookId,
        type == ThumbnailType.book.rawValue
      else { return }
      Task {
        await CoverBackgroundProvider.shared.invalidate(
          instanceId: item.instanceId, id: item.bookId, type: .book)
        coverArtwork = await CoverBackgroundProvider.shared.backgroundImage(
          instanceId: item.instanceId, id: item.bookId, type: .book)
      }
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
        if progress > 0 && progress < 1 {
          Text(progress, format: .percent.precision(.fractionLength(0)))
          Text("•")
        }
        if progress == 1 {
          Image(systemName: "checkmark.circle.fill")
            .foregroundColor(secondaryTextColor)
            .font(.system(tertiaryTextStyle))
        }
        Text(progress == 1 ? completedMetaText : "\(item.mediaPagesCount) pages")
      }
      if item.downloadStatus != .notDownloaded {
        Spacer()
        Image(systemName: item.downloadStatus.displayIcon)
          .foregroundColor(item.downloadStatus.displayColor)
          .font(.system(tertiaryTextStyle))
      }
    }
    .font(.system(secondaryTextStyle))
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
