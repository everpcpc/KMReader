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
    HStack(spacing: 12) {
      NavigationLink(value: NavDestination.seriesDetail(seriesId: komgaSeries.seriesId)) {
        ThumbnailImage(id: komgaSeries.seriesId, type: .series, width: 80)
      }

      VStack(alignment: .leading, spacing: 6) {
        NavigationLink(value: NavDestination.seriesDetail(seriesId: komgaSeries.seriesId)) {
          Text(komgaSeries.metaTitle)
            .font(.callout)
            .lineLimit(2)
        }

        HStack {
          VStack(alignment: .leading, spacing: 4) {
            Label(seriesDto.statusDisplayName, systemImage: seriesDto.statusIcon)
              .font(.footnote)
              .foregroundColor(seriesDto.statusColor)

            if let releaseDate = komgaSeries.booksMetaReleaseDate {
              Label("Release: \(releaseDate)", systemImage: "calendar")
                .font(.caption)
                .foregroundColor(.secondary)
            } else {
              Label("Last Updated: \(seriesDto.lastUpdatedDisplay)", systemImage: "clock")
                .font(.caption)
                .foregroundColor(.secondary)
            }

            HStack {
              if komgaSeries.deleted {
                Text("Unavailable")
                  .foregroundColor(.red)
              } else if komgaSeries.oneshot {
                Text("Oneshot")
                  .foregroundColor(.blue)
                if komgaSeries.booksReadCount > 0 {
                  Text("•")
                    .foregroundColor(.secondary)
                  Label("readStatus.read", systemImage: "checkmark.circle.fill")
                    .foregroundColor(seriesDto.readStatusColor)
                }
              } else {
                HStack {
                  Label("\(komgaSeries.booksCount) books", systemImage: "book")
                    .foregroundColor(.secondary)
                  Text("•")
                    .foregroundColor(.secondary)
                  if komgaSeries.booksUnreadCount > 0 {
                    Label("\(komgaSeries.booksUnreadCount) unread", systemImage: "circlebadge")
                      .foregroundColor(seriesDto.readStatusColor)
                  } else {
                    Label("All read", systemImage: "checkmark.circle.fill")
                      .foregroundColor(seriesDto.readStatusColor)
                  }
                }
              }
            }.font(.footnote)
          }

          Spacer()

          if komgaSeries.downloadStatus != .notDownloaded {
            Image(systemName: komgaSeries.downloadStatus.icon)
              .foregroundColor(komgaSeries.downloadStatus.color)
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
