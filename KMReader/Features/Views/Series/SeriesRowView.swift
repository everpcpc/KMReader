//
//  SeriesRowView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftData
import SwiftUI

struct SeriesRowView: View {
  @Bindable var komgaSeries: KomgaSeries
  var onActionCompleted: (() -> Void)? = nil

  @State private var showCollectionPicker = false
  @State private var showDeleteConfirmation = false
  @State private var showEditSheet = false

  var seriesDto: Series {
    komgaSeries.toSeries()
  }

  var body: some View {
    CardView {
      HStack(spacing: 12) {
        ThumbnailImage(id: komgaSeries.seriesId, type: .series, width: 80)

        VStack(alignment: .leading, spacing: 6) {
          Text(komgaSeries.metaTitle)
            .font(.callout)
            .lineLimit(2)

          Label(seriesDto.statusDisplayName, systemImage: seriesDto.statusIcon)
            .font(.footnote)
            .foregroundColor(seriesDto.statusColor)

          Group {
            if komgaSeries.deleted {
              Text("Unavailable")
                .foregroundColor(.red)
            } else {
              HStack {
                if komgaSeries.booksUnreadCount > 0 {
                  Label("\(komgaSeries.booksUnreadCount) unread", systemImage: "circlebadge")
                    .foregroundColor(seriesDto.readStatusColor)
                } else {
                  Label("All read", systemImage: "checkmark.circle.fill")
                    .foregroundColor(seriesDto.readStatusColor)
                }
                Text("•")
                  .foregroundColor(.secondary)
                Label("\(komgaSeries.booksCount) books", systemImage: "book")
                  .foregroundColor(.secondary)
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
            }
          }.font(.caption)

          if let releaseDate = komgaSeries.booksMetaReleaseDate {
            Label("Release: \(releaseDate)", systemImage: "calendar")
              .font(.caption)
              .foregroundColor(.secondary)
          } else {
            Label("Last Updated: \(seriesDto.lastUpdatedDisplay)", systemImage: "clock")
              .font(.caption)
              .foregroundColor(.secondary)
          }
        }

        Spacer()

        Image(systemName: "chevron.right")
          .foregroundColor(.secondary)
      }
    }
    .adaptiveButtonStyle(.plain)
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
      SeriesEditSheet(series: seriesDto)
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
