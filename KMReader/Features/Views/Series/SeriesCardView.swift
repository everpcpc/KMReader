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
  let cardWidth: CGFloat
  var onActionCompleted: (() -> Void)? = nil

  @AppStorage("showSeriesCardTitle") private var showTitle: Bool = true

  @State private var showCollectionPicker = false
  @State private var showDeleteConfirmation = false
  @State private var showEditSheet = false

  var body: some View {
    CardView {
      VStack(alignment: .leading, spacing: 6) {
        ThumbnailImage(id: komgaSeries.seriesId, type: .series, width: cardWidth - 8) {
          ZStack {
            if komgaSeries.booksUnreadCount > 0 {
              VStack(alignment: .trailing) {
                UnreadCountBadge(count: komgaSeries.booksUnreadCount)
                  .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
              }
            }
          }
        }

        VStack(alignment: .leading, spacing: 2) {
          if showTitle {
            Text(komgaSeries.metaTitle)
              .font(.caption)
              .foregroundColor(.primary)
              .lineLimit(1)
          }
          Group {
            if komgaSeries.deleted {
              Text("Unavailable")
                .foregroundColor(.red)
            } else {
              HStack(spacing: 4) {
                Text("\(komgaSeries.booksCount) books")
                if komgaSeries.oneshot {
                  Text("•")
                  Text("Oneshot")
                    .foregroundColor(.blue)
                }
                if komgaSeries.downloadStatus != .notDownloaded {
                  Image(systemName: komgaSeries.downloadStatus.icon)
                    .foregroundColor(komgaSeries.downloadStatus.color)
                    .frame(width: PlatformHelper.iconSize, height: PlatformHelper.iconSize)
                    .padding(.horizontal, 4)
                }
              }
              .foregroundColor(.secondary)
            }
          }.font(.caption2)
        }
      }
    }
    .frame(width: cardWidth, alignment: .leading)
    .adaptiveButtonStyle(.plain)
    .frame(maxHeight: .infinity, alignment: .top)
    .contentShape(Rectangle())
    .contextMenu {
      SeriesContextMenu(
        komgaSeries: komgaSeries,
        onActionCompleted: onActionCompleted,
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
        },
        onComplete: {
          // Create already adds series, just refresh
          onActionCompleted?()
        }
      )
    }
    .sheet(isPresented: $showEditSheet) {
      SeriesEditSheet(series: komgaSeries.toSeries())
        .onDisappear {
          onActionCompleted?()
        }
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
          onActionCompleted?()
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
          onActionCompleted?()
        }
      } catch {
        await MainActor.run {
          ErrorManager.shared.alert(error: error)
        }
      }
    }
  }
}
