//
//  SeriesCardView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftData
import SwiftUI

struct SeriesCardView: View {
  @Bindable var komgaSeries: KomgaSeries

  @AppStorage("coverOnlyCards") private var coverOnlyCards: Bool = false
  @AppStorage("thumbnailShowUnreadIndicator") private var thumbnailShowUnreadIndicator: Bool = true

  @State private var showCollectionPicker = false
  @State private var showDeleteConfirmation = false
  @State private var showEditSheet = false

  var navDestination: NavDestination {
    if komgaSeries.oneshot {
      return NavDestination.oneshotDetail(seriesId: komgaSeries.seriesId)
    } else {
      return NavDestination.seriesDetail(seriesId: komgaSeries.seriesId)
    }
  }

  var progress: Double {
    guard komgaSeries.booksCount > 0 else { return 0 }
    return Double(komgaSeries.booksReadCount) / Double(komgaSeries.booksCount)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      NavigationLink(value: navDestination) {
        ThumbnailImage(
          id: komgaSeries.seriesId, type: .series, shadowStyle: .platform, alignment: .bottom
        ) {
          ZStack {
            if thumbnailShowUnreadIndicator && komgaSeries.booksUnreadCount > 0 {
              VStack(alignment: .trailing) {
                UnreadCountBadge(count: komgaSeries.booksUnreadCount)
                  .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
              }
            }
          }
        }
      }
      .focusPadding()
      .adaptiveButtonStyle(.plain)
      .contextMenu {
        SeriesContextMenu(
          komgaSeries: komgaSeries,
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
        .id(komgaSeries.seriesId)
      }

      if !coverOnlyCards {
        VStack(alignment: .leading) {
          Text(komgaSeries.metaTitle)
            .lineLimit(1)

          HStack(spacing: 4) {
            if komgaSeries.isUnavailable {
              Text("Unavailable")
                .foregroundColor(.red)
            } else if komgaSeries.oneshot {
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
              Text("\(komgaSeries.booksCount) books")
                .lineLimit(1)
            }
            if komgaSeries.downloadStatus != .notDownloaded {
              Spacer()
              Image(systemName: komgaSeries.downloadStatus.icon)
                .foregroundColor(komgaSeries.downloadStatus.color)
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
        seriesIds: [komgaSeries.seriesId],
        onSelect: { collectionId in
          addToCollection(collectionId: collectionId)
        }
      )
    }
    .sheet(isPresented: $showEditSheet) {
      SeriesEditSheet(series: komgaSeries.toSeries())
    }
  }

  private func addToCollection(collectionId: String) {
    Task {
      do {
        try await CollectionService.shared.addSeriesToCollection(
          collectionId: collectionId,
          seriesIds: [komgaSeries.seriesId]
        )
        await MainActor.run {
          ErrorManager.shared.notify(
            message: String(localized: "notification.series.addedToCollection"))
        }
      } catch {
        await MainActor.run {
          ErrorManager.shared.alert(error: error)
        }
      }
    }
  }

  private func deleteSeries() {
    Task {
      do {
        try await SeriesService.shared.deleteSeries(seriesId: komgaSeries.seriesId)
        await MainActor.run {
          ErrorManager.shared.notify(message: String(localized: "notification.series.deleted"))
        }
      } catch {
        await MainActor.run {
          ErrorManager.shared.alert(error: error)
        }
      }
    }
  }
}
