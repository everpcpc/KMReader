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

  var series: Series {
    komgaSeries.toSeries()
  }

  var downloadStatus: SeriesDownloadStatus {
    komgaSeries.downloadStatus
  }

  var body: some View {
    HStack(spacing: 12) {
      NavigationLink(value: NavDestination.seriesDetail(seriesId: series.id)) {
        ThumbnailImage(id: series.id, type: .series, width: 80)
      }

      VStack(alignment: .leading, spacing: 6) {
        NavigationLink(value: NavDestination.seriesDetail(seriesId: series.id)) {
          Text(series.metadata.title)
            .font(.callout)
            .lineLimit(2)
        }

        HStack {
          VStack(alignment: .leading, spacing: 4) {
            Label(series.statusDisplayName, systemImage: series.statusIcon)
              .font(.footnote)
              .foregroundColor(series.statusColor)

            if let releaseDate = series.booksMetadata.releaseDate {
              Label("Release: \(releaseDate)", systemImage: "calendar")
                .font(.caption)
                .foregroundColor(.secondary)
            } else {
              Label("Last Updated: \(series.lastUpdatedDisplay)", systemImage: "clock")
                .font(.caption)
                .foregroundColor(.secondary)
            }

            HStack {
              if series.deleted {
                Text("Unavailable")
                  .foregroundColor(.red)
              } else if series.oneshot {
                Text("Oneshot")
                  .foregroundColor(.blue)
                if series.booksReadCount > 0 {
                  Text("•")
                    .foregroundColor(.secondary)
                  Label("readStatus.read", systemImage: "checkmark.circle.fill")
                    .foregroundColor(series.readStatusColor)
                }
              } else {
                HStack {
                  Label("\(series.booksCount) books", systemImage: "book")
                    .foregroundColor(.secondary)
                  Text("•")
                    .foregroundColor(.secondary)
                  if series.booksUnreadCount > 0 {
                    Label("\(series.booksUnreadCount) unread", systemImage: "circlebadge")
                      .foregroundColor(series.readStatusColor)
                  } else {
                    Label("All read", systemImage: "checkmark.circle.fill")
                      .foregroundColor(series.readStatusColor)
                  }
                }
              }
            }.font(.footnote)
          }

          Spacer()

          if downloadStatus != .notDownloaded {
            Image(systemName: downloadStatus.icon)
              .foregroundColor(downloadStatus.color)
          }
          Menu {
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
          } label: {
            HStack {
              Image(systemName: "ellipsis")
                .padding(.horizontal, 4)
            }
            .foregroundColor(.secondary)
            .contentShape(Rectangle())
          }
        }
      }
    }
    .adaptiveButtonStyle(.plain)
    .contentShape(Rectangle())
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
        seriesIds: [series.id],
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
      SeriesEditSheet(series: series)
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
          seriesIds: [series.id]
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
        try await SeriesService.shared.deleteSeries(seriesId: series.id)
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
