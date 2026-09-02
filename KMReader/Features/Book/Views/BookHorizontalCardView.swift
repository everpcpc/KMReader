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

  /// Compact density shows the title on a single line so the card height can
  /// actually shrink with the cover instead of being held up by reserved text space.
  private var titleLineLimit: Int {
    gridDensity < GridDensity.standard.rawValue ? 1 : 2
  }

  private var progress: Double {
    guard let progressPage = item.progressPage else { return 0 }
    guard item.mediaPagesCount > 0 else { return 0 }
    return Double(progressPage) / Double(item.mediaPagesCount)
  }

  /// The ring only appears for in-progress books; unread and completed books
  /// keep the plain bottom bar to avoid visual noise.
  private var showsProgressRing: Bool {
    !item.isUnavailable && item.media.statusValue == .ready && progress > 0 && progress < 1
  }

  /// The cover slot uses a fixed √2 height ratio and always drives the row
  /// height, so this ring (smaller than the cover) can never affect the card
  /// height. The 16pt total inset keeps its top/bottom/right margins equal.
  private var progressRingDiameter: CGFloat {
    coverWidth * CoverAspectRatio.heightToWidth - 16
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
    HStack(alignment: .top, spacing: 10) {
      Button {
        onReadBook?(false)
      } label: {
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
      }
      .adaptiveButtonStyle(.plain)

      Button {
        onReadBook?(false)
      } label: {
        HStack(spacing: 8) {
          VStack(alignment: .leading, spacing: 2) {
            if item.oneshot {
              Text("Oneshot")
                .font(.caption)
                .foregroundColor(.blue)
                .lineLimit(1)
            } else if !item.seriesTitle.isEmpty {
              Text(item.seriesTitle)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
            }

            Text(bookTitleLine)
              .font(.footnote)
              .foregroundColor(item.isCompleted ? .secondary : .primary)
              .lineLimit(titleLineLimit, reservesSpace: true)
              .multilineTextAlignment(.leading)

            Spacer(minLength: 2)

            bottomBar
          }
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)

          if showsProgressRing {
            ProgressRingView(progress: progress, diameter: progressRingDiameter)
              .frame(maxHeight: .infinity, alignment: .center)
              .padding(.trailing, 8)
          }
        }
        .contentShape(Rectangle())
      }
      .adaptiveButtonStyle(.plain)
    }
    .padding(8)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background {
      RoundedRectangle(cornerRadius: 12)
        .fill(.regularMaterial)
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
        if progress == 1 {
          Image(systemName: "checkmark.circle.fill")
            .foregroundColor(.secondary)
            .font(.caption2)
        }
        Text(progress == 1 ? completedMetaText : "\(item.mediaPagesCount) pages")
      }
      if item.downloadStatus != .notDownloaded {
        Image(systemName: item.downloadStatus.displayIcon)
          .foregroundColor(item.downloadStatus.displayColor)
          .font(.caption2)
      }
    }
    .font(.caption)
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
