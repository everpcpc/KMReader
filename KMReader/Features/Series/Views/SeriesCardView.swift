//
// SeriesCardView.swift
//
//

import SwiftUI

struct SeriesCardView: View {
  let series: Series
  let localState: KomgaSeriesLocalStateRecord?

  @AppStorage("coverOnlyCards") private var coverOnlyCards: Bool = false
  @AppStorage("cardTextOverlayMode") private var cardTextOverlayMode: Bool = false
  @AppStorage("thumbnailShowUnreadIndicator") private var thumbnailShowUnreadIndicator: Bool = true

  @State private var showCollectionPicker = false
  @State private var showDeleteConfirmation = false
  @State private var showEditSheet = false

  var navDestination: NavDestination {
    if series.oneshot {
      return NavDestination.oneshotDetail(seriesId: series.id)
    } else {
      return NavDestination.seriesDetail(seriesId: series.id)
    }
  }

  var progress: Double {
    guard series.booksCount > 0 else { return 0 }
    return Double(series.booksReadCount) / Double(series.booksCount)
  }

  private var downloadStatus: SeriesDownloadStatus {
    (localState ?? .empty(instanceId: AppConfig.current.instanceId, seriesId: series.id))
      .downloadStatus(totalBooks: series.booksCount)
  }

  private var offlinePolicy: SeriesOfflinePolicy {
    localState?.offlinePolicy ?? .manual
  }

  private var offlinePolicyLimit: Int {
    localState?.offlinePolicyLimit ?? 0
  }

  private var contentSpacing: CGFloat {
    cardTextOverlayMode ? 0 : 12
  }

  var body: some View {
    VStack(alignment: .leading, spacing: contentSpacing) {
      ThumbnailImage(
        id: series.id,
        type: .series,
        shadowStyle: .platform,
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
          if thumbnailShowUnreadIndicator && series.booksUnreadCount > 0 {
            VStack(alignment: .trailing) {
              UnreadCountBadge(count: series.booksUnreadCount)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            }
          }
        }
      } menu: {
        SeriesContextMenu(
          seriesId: series.id,
          menuTitle: series.metadata.title,
          downloadStatus: downloadStatus,
          offlinePolicy: offlinePolicy,
          offlinePolicyLimit: offlinePolicyLimit,
          booksUnreadCount: series.booksUnreadCount,
          booksReadCount: series.booksReadCount,
          booksInProgressCount: series.booksInProgressCount,
          onShowCollectionPicker: {
            showCollectionPicker = true
          },
          onDeleteRequested: {
            showDeleteConfirmation = true
          },
          onEditRequested: {
            showEditSheet = true
          }
        )
      }

      if !cardTextOverlayMode && !coverOnlyCards {
        VStack(alignment: .leading) {
          Text(series.metadata.title)
            .lineLimit(1)

          HStack(spacing: 4) {
            if series.deleted {
              Text("Unavailable")
                .foregroundColor(.red)
            } else if series.oneshot {
              Text("Oneshot")
                .foregroundColor(.blue)
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
              Text("\(series.booksCount) books")
                .lineLimit(1)
            }
            if downloadStatus != .notDownloaded {
              Spacer()
              Image(systemName: downloadStatus.icon)
                .foregroundColor(downloadStatus.color)
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
        seriesId: series.id,
        onSelect: { collectionId in
          addToCollection(collectionId: collectionId)
        }
      )
    }
    .sheet(isPresented: $showEditSheet) {
      SeriesEditSheet(series: series)
    }
  }

  @ViewBuilder
  private var overlayTextContent: some View {
    let style = CardOverlayTextStyle.standard

    CardOverlayTextStack(title: series.metadata.title, style: style) {
      HStack(spacing: 4) {
        if series.deleted {
          Text("Unavailable")
            .foregroundColor(.red)
        } else if series.oneshot {
          Text("Oneshot")
            .foregroundColor(.blue)
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
          Text("\(series.booksCount) books")
            .lineLimit(1)
        }
        if downloadStatus != .notDownloaded {
          Spacer()
          Image(systemName: downloadStatus.icon)
            .foregroundColor(downloadStatus.color)
            .font(.caption2)
        }
      }
    }
  }

  private func addToCollection(collectionId: String) {
    Task {
      do {
        try await CollectionService.shared.addSeriesToCollection(
          collectionId: collectionId,
          seriesIds: [series.id]
        )
        ErrorManager.shared.notify(
          message: String(localized: "notification.series.addedToCollection"))
      } catch {
        ErrorManager.shared.alert(error: error)
      }
    }
  }

  private func deleteSeries() {
    Task {
      do {
        try await SeriesService.shared.deleteSeries(seriesId: series.id)
        ErrorManager.shared.notify(message: String(localized: "notification.series.deleted"))
      } catch {
        ErrorManager.shared.alert(error: error)
      }
    }
  }
}
