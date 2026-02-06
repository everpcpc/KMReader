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

  @State private var showCollectionPicker = false
  @State private var showDeleteConfirmation = false
  @State private var showEditSheet = false

  var series: Series {
    komgaSeries.toSeries()
  }

  var downloadStatus: SeriesDownloadStatus {
    komgaSeries.downloadStatus
  }

  var navDestination: NavDestination {
    if komgaSeries.oneshot {
      return NavDestination.oneshotDetail(seriesId: komgaSeries.seriesId)
    } else {
      return NavDestination.seriesDetail(seriesId: komgaSeries.seriesId)
    }
  }

  var progress: Double {
    guard komgaSeries.booksCount > 0 else { return 0 }
    guard komgaSeries.booksReadCount > 0 else { return 0 }
    return Double(komgaSeries.booksReadCount) / Double(komgaSeries.booksCount)
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
          Image(systemName: "ellipsis")
            .hidden()
            .overlay(
              Menu {
                SeriesContextMenu(
                  seriesId: komgaSeries.seriesId,
                  menuTitle: komgaSeries.metaTitle,
                  downloadStatus: komgaSeries.downloadStatus,
                  offlinePolicy: komgaSeries.offlinePolicy,
                  offlinePolicyLimit: komgaSeries.offlinePolicyLimit,
                  booksUnreadCount: komgaSeries.booksUnreadCount,
                  booksReadCount: komgaSeries.booksReadCount,
                  booksInProgressCount: komgaSeries.booksInProgressCount,
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
              } label: {
                Image(systemName: "ellipsis")
                  .foregroundColor(.secondary)
                  .frame(width: 40, height: 40)
                  .contentShape(Rectangle())
              }
              .appMenuStyle()
              .adaptiveButtonStyle(.plain)
            )
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
        try await SeriesService.shared.deleteSeries(seriesId: series.id)
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
