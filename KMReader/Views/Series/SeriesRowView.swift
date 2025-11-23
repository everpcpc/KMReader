//
//  SeriesRowView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct SeriesRowView: View {
  let series: Series
  var onActionCompleted: (() -> Void)? = nil

  @State private var showCollectionPicker = false

  private var thumbnailURL: URL? {
    SeriesService.shared.getSeriesThumbnailURL(id: series.id)
  }

  var body: some View {
    HStack(spacing: 12) {
      ThumbnailImage(url: thumbnailURL, showPlaceholder: false, width: 80, cornerRadius: 6)

      VStack(alignment: .leading, spacing: 6) {
        Text(series.metadata.title)
          .font(.callout)
          .lineLimit(2)

        Label(series.statusDisplayName, systemImage: series.statusIcon)
          .font(.footnote)
          .foregroundColor(series.statusColor)

        Group {
          if series.deleted {
            Text("Unavailable")
              .foregroundColor(.red)
          } else {
            HStack {
              if series.booksUnreadCount > 0 {
                Label("\(series.booksUnreadCount) unread", systemImage: "circlebadge")
                  .foregroundColor(series.readStatusColor)
              } else {
                Label("All read", systemImage: "checkmark.circle.fill")
                  .foregroundColor(series.readStatusColor)
              }
              Text("•")
                .foregroundColor(.secondary)
              Label("\(series.booksCount) books", systemImage: "book")
                .foregroundColor(.secondary)
              if series.oneshot {
                Text("•")
                Text("Oneshot")
                  .foregroundColor(.blue)
              }
            }
          }
        }.font(.caption)

        Label(series.lastUpdatedDisplay, systemImage: "clock")
          .font(.caption)
          .foregroundColor(.secondary)
      }

      Spacer()

      Image(systemName: "chevron.right")
        .foregroundColor(.secondary)
    }
    .contentShape(Rectangle())
    .contextMenu {
      SeriesContextMenu(
        series: series,
        onActionCompleted: onActionCompleted,
        onShowCollectionPicker: {
          showCollectionPicker = true
        }
      )
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
  }

  private func addToCollection(collectionId: String) {
    Task {
      do {
        try await CollectionService.shared.addSeriesToCollection(
          collectionId: collectionId,
          seriesIds: [series.id]
        )
        await MainActor.run {
          ErrorManager.shared.notify(message: "Series added to collection")
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
