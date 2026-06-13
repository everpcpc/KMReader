//
// SeriesCardView.swift
//
//

import SwiftUI

struct SeriesCardView: View {
  let item: SeriesDisplayItem
  var onMutationCompleted: (() -> Void)? = nil

  @AppStorage("coverOnlyCards") private var coverOnlyCards: Bool = false
  @AppStorage("cardTextOverlayMode") private var cardTextOverlayMode: Bool = false
  @AppStorage("thumbnailShowUnreadIndicator") private var thumbnailShowUnreadIndicator: Bool = true
  @AppStorage("thumbnailBlurUnreadCovers") private var thumbnailBlurUnreadCovers: Bool = false

  @State private var showCollectionPicker = false
  @State private var showDeleteConfirmation = false
  @State private var showEditSheet = false

  var navDestination: NavDestination {
    if item.oneshot {
      return NavDestination.oneshotDetail(seriesId: item.seriesId)
    } else {
      return NavDestination.seriesDetail(seriesId: item.seriesId)
    }
  }

  var progress: Double {
    guard item.booksCount > 0 else { return 0 }
    return Double(item.booksReadCount) / Double(item.booksCount)
  }

  private var contentSpacing: CGFloat {
    cardTextOverlayMode ? 0 : 12
  }

  private var coverBlurRadius: CGFloat {
    thumbnailBlurUnreadCovers && item.isUnread ? CoverBlurStyle.unreadRadius : 0
  }

  var body: some View {
    VStack(alignment: .leading, spacing: contentSpacing) {
      ThumbnailImage(
        id: item.seriesId,
        type: .series,
        shadowStyle: .platform,
        contentBlurRadius: coverBlurRadius,
        alignment: .bottom,
        navigationLink: navDestination,
        preserveAspectRatioOverride: cardTextOverlayMode ? false : nil
      ) {
        ZStack {
          if cardTextOverlayMode {
            CardTextOverlay(cornerRadius: 8) {
              overlayTextContent
            }
          }
          if thumbnailShowUnreadIndicator && item.booksUnreadCount > 0 {
            VStack(alignment: .trailing) {
              UnreadCountBadge(count: item.booksUnreadCount)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            }
          }
        }
      } menu: {
        SeriesContextMenu(
          seriesId: item.seriesId,
          menuTitle: item.metaTitle,
          downloadStatus: item.downloadStatus,
          offlinePolicy: item.offlinePolicy,
          offlinePolicyLimit: item.offlinePolicyLimit,
          booksUnreadCount: item.booksUnreadCount,
          booksReadCount: item.booksReadCount,
          booksInProgressCount: item.booksInProgressCount,
          onShowCollectionPicker: {
            showCollectionPicker = true
          },
          onDeleteRequested: {
            showDeleteConfirmation = true
          },
          onEditRequested: {
            showEditSheet = true
          },
          onMutationCompleted: onMutationCompleted
        )
      }

      if !cardTextOverlayMode && !coverOnlyCards {
        VStack(alignment: .leading) {
          Text(item.metaTitle)
            .lineLimit(1)

          HStack(spacing: 4) {
            if item.isUnavailable {
              Text("Unavailable")
                .foregroundColor(.red)
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
              Text("\(item.booksCount) books")
                .lineLimit(1)
            }
            if item.downloadStatus != .notDownloaded {
              Spacer()
              Image(systemName: item.downloadStatus.icon)
                .foregroundColor(item.downloadStatus.color)
                .font(.caption2)
            }
          }
          .font(.caption)
          .foregroundColor(.secondary)
        }.font(.footnote)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .frame(maxHeight: .infinity, alignment: .top)
    .alert("Delete Series", isPresented: $showDeleteConfirmation) {
      Button("Cancel", role: .cancel) {}
      Button("Delete", role: .destructive) {
        deleteSeries()
      }
    } message: {
      Text("Are you sure you want to delete this series? This action cannot be undone.")
    }
    .sheet(isPresented: $showCollectionPicker) {
      CollectionPickerSheet(
        seriesId: item.seriesId,
        onSelect: { collectionId in
          addToCollection(collectionId: collectionId)
        }
      )
    }
    .sheet(isPresented: $showEditSheet) {
      SeriesEditSheet(series: item.series)
    }
  }

  @ViewBuilder
  private var overlayTextContent: some View {
    let style = CardOverlayTextStyle.standard

    CardOverlayTextStack(title: item.metaTitle, style: style) {
      HStack(spacing: 4) {
        if item.isUnavailable {
          Text("Unavailable")
            .foregroundColor(.red)
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
          Text("\(item.booksCount) books")
            .lineLimit(1)
        }
        if item.downloadStatus != .notDownloaded {
          Spacer()
          Image(systemName: item.downloadStatus.icon)
            .foregroundColor(item.downloadStatus.color)
            .font(.caption2)
        }
      }
    }
  }

  private func addToCollection(collectionId: String) {
    Task {
      do {
        try await CollectionService.addSeriesToCollection(
          collectionId: collectionId,
          seriesIds: [item.seriesId]
        )
        ErrorManager.shared.notify(
          message: String(localized: "notification.series.addedToCollection"))
        onMutationCompleted?()
      } catch {
        ErrorManager.shared.alert(error: error)
      }
    }
  }

  private func deleteSeries() {
    Task {
      do {
        try await SeriesService.deleteSeries(seriesId: item.seriesId)
        ErrorManager.shared.notify(message: String(localized: "notification.series.deleted"))
        onMutationCompleted?()
      } catch {
        ErrorManager.shared.alert(error: error)
      }
    }
  }
}
