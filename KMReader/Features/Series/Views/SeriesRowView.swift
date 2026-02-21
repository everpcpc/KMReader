//
// SeriesRowView.swift
//
//

import SwiftUI

struct SeriesRowView: View {
  let series: Series
  let localState: KomgaSeriesLocalStateRecord?

  @State private var showCollectionPicker = false
  @State private var showDeleteConfirmation = false
  @State private var showEditSheet = false

  var downloadStatus: SeriesDownloadStatus {
    (localState ?? .empty(instanceId: AppConfig.current.instanceId, seriesId: series.id))
      .downloadStatus(totalBooks: series.booksCount)
  }

  private var offlinePolicy: SeriesOfflinePolicy {
    localState?.offlinePolicy ?? .manual
  }

  private var offlinePolicyLimit: Int {
    localState?.offlinePolicyLimit ?? 0
  }

  var navDestination: NavDestination {
    if series.oneshot {
      return NavDestination.oneshotDetail(seriesId: series.id)
    } else {
      return NavDestination.seriesDetail(seriesId: series.id)
    }
  }

  var progress: Double {
    guard series.booksCount > 0 else { return 0 }
    guard series.booksReadCount > 0 else { return 0 }
    return Double(series.booksReadCount) / Double(series.booksCount)
  }

  var body: some View {
    HStack(spacing: 12) {
      NavigationLink(value: navDestination) {
        ThumbnailImage(id: series.id, type: .series, width: 80)
      }
      .adaptiveButtonStyle(.plain)

      VStack(alignment: .leading, spacing: 6) {
        NavigationLink(value: navDestination) {
          Text(series.metadata.title)
            .font(.callout)
            .lineLimit(2)
        }.adaptiveButtonStyle(.plain)

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
              } else {
                HStack(spacing: 4) {
                  Label("\(series.booksCount) books", systemImage: ContentIcon.book)
                  Text("•")
                  if series.booksUnreadCount > 0 {
                    Image(systemName: "circle.righthalf.filled")
                      .foregroundColor(series.readStatusColor)
                    Text("\(series.booksUnreadCount) unread")
                      .foregroundColor(series.readStatusColor)
                    Text("•")
                    Text("\(progress * 100, specifier: "%.0f")%")
                  } else {
                    Label("All read", systemImage: "checkmark.circle.fill")
                      .foregroundColor(series.readStatusColor)
                  }
                }
              }
            }
            .font(.footnote)
            .foregroundColor(.secondary)
          }

          Spacer()

          if downloadStatus != .notDownloaded {
            Image(systemName: downloadStatus.icon)
              .foregroundColor(downloadStatus.color)
          }
          EllipsisMenuButton {
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
            .id(series.id)
          }
        }
      }
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
