//
// SeriesRowView.swift
//
//

import SwiftUI

struct SeriesRowView: View {
  let item: SeriesDisplayItem
  var onMutationCompleted: (() -> Void)? = nil

  @AppStorage("thumbnailBlurUnreadCovers") private var thumbnailBlurUnreadCovers: Bool = false

  @State private var showCollectionPicker = false
  @State private var showDeleteConfirmation = false
  @State private var showEditSheet = false

  var series: Series {
    item.series
  }

  var downloadStatus: SeriesDownloadStatus {
    item.downloadStatus
  }

  var navDestination: NavDestination {
    if item.oneshot {
      return NavDestination.oneshotDetail(seriesId: item.seriesId)
    } else {
      return NavDestination.seriesDetail(seriesId: item.seriesId)
    }
  }

  var progress: Double {
    guard item.booksCount > 0 else { return 0 }
    guard item.booksReadCount > 0 else { return 0 }
    return Double(item.booksReadCount) / Double(item.booksCount)
  }

  private var coverBlurRadius: CGFloat {
    thumbnailBlurUnreadCovers && item.isUnread ? CoverBlurStyle.unreadRadius : 0
  }

  var body: some View {
    HStack(spacing: 12) {
      NavigationLink(value: navDestination) {
        ThumbnailImage(
          id: series.id,
          type: .series,
          contentBlurRadius: coverBlurRadius,
          width: 80
        )
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
            if series.oneshot {
              Label("Oneshot", systemImage: "book.closed")
                .font(.footnote)
                .foregroundColor(.blue)
            } else {
              Label(series.statusDisplayName, systemImage: series.statusIcon)
                .font(.footnote)
                .foregroundColor(series.statusColor)
            }

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
              } else {
                readingProgressSummary
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
            .id(item.seriesId)
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

  @ViewBuilder
  private var readingProgressSummary: some View {
    HStack(spacing: 4) {
      Label("\(series.booksCount) books", systemImage: ContentIcon.book)
      Text("•")

      switch series.readStatus {
      case .read:
        Label("All read", systemImage: series.readStatusIcon)
          .foregroundColor(series.readStatusColor)
      case .inProgress:
        Image(systemName: series.readStatusIcon)
          .foregroundColor(series.readStatusColor)
        Text(series.booksUnreadCount > 0 ? "\(series.booksUnreadCount) unread" : series.readStatusDisplayName)
          .foregroundColor(series.readStatusColor)
        Text("•")
        Text(progress, format: .percent.precision(.fractionLength(0)))
      case .unread:
        Image(systemName: "circle.righthalf.filled")
          .foregroundColor(series.readStatusColor)
        Text("\(series.booksUnreadCount) unread")
          .foregroundColor(series.readStatusColor)
        Text("•")
        Text(progress, format: .percent.precision(.fractionLength(0)))
      }
    }
  }

  private func addToCollection(collectionId: String) {
    Task {
      do {
        try await CollectionService.addSeriesToCollection(
          collectionId: collectionId,
          seriesIds: [series.id]
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
        try await SeriesService.deleteSeries(seriesId: series.id)
        ErrorManager.shared.notify(message: String(localized: "notification.series.deleted"))
        onMutationCompleted?()
      } catch {
        ErrorManager.shared.alert(error: error)
      }
    }
  }
}
