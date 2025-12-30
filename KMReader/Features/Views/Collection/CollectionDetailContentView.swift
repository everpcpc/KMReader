//
//  CollectionDetailContentView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct CollectionDetailContentView: View {
  let collection: SeriesCollection
  @Binding var thumbnailRefreshTrigger: Int

  var body: some View {
    VStack(alignment: .leading) {
      Text(collection.name)
        .font(.title2)

      HStack(alignment: .top) {
        ThumbnailImage(
          id: collection.id, type: .collection,
          width: PlatformHelper.detailThumbnailWidth,
          refreshTrigger: thumbnailRefreshTrigger
        )
        .thumbnailFocus()

        VStack(alignment: .leading) {
          VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
              InfoChip(
                labelKey: "\(collection.seriesIds.count) series",
                systemImage: "square.grid.2x2",
                backgroundColor: Color.blue.opacity(0.2),
                foregroundColor: .blue
              )
              if collection.ordered {
                InfoChip(
                  labelKey: "Ordered",
                  systemImage: "arrow.up.arrow.down",
                  backgroundColor: Color.cyan.opacity(0.2),
                  foregroundColor: .cyan
                )
              }
            }
            InfoChip(
              labelKey: "Created: \(formatDate(collection.createdDate))",
              systemImage: "calendar.badge.plus",
              backgroundColor: Color.blue.opacity(0.2),
              foregroundColor: .blue
            )
            InfoChip(
              labelKey: "Modified: \(formatDate(collection.lastModifiedDate))",
              systemImage: "clock",
              backgroundColor: Color.purple.opacity(0.2),
              foregroundColor: .purple
            )
          }
        }
      }
    }
  }

  private func formatDate(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .none
    return formatter.string(from: date)
  }
}
