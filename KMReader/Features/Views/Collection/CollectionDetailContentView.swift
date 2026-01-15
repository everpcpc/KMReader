//
//  CollectionDetailContentView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct CollectionDetailContentView: View {
  let collection: SeriesCollection
  @State private var thumbnailRefreshKey = UUID()

  var body: some View {
    VStack(alignment: .leading) {
      Text(collection.name)
        .font(.title2)

      HStack(alignment: .top) {
        ThumbnailImage(
          id: collection.id,
          type: .collection,
          width: PlatformHelper.detailThumbnailWidth,
          isTransitionSource: false,
          onAction: {}
        ) {
        } menu: {
          Button {
            Task {
              do {
                _ = try await ThumbnailCache.shared.ensureThumbnail(
                  id: collection.id,
                  type: .collection,
                  force: true
                )
                await MainActor.run {
                  thumbnailRefreshKey = UUID()
                  ErrorManager.shared.notify(
                    message: String(localized: "notification.cover.refreshed"))
                }
              } catch {
                await MainActor.run {
                  ErrorManager.shared.notify(
                    message: String(localized: "notification.cover.refreshFailed"))
                }
              }
            }
          } label: {
            Label(String(localized: "Refresh Cover"), systemImage: "arrow.clockwise")
          }
        }
        .id(thumbnailRefreshKey)

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
              labelKey: "Created: \(collection.createdDate.formattedMediumDate)",
              systemImage: "calendar.badge.plus",
              backgroundColor: Color.blue.opacity(0.2),
              foregroundColor: .blue
            )
            InfoChip(
              labelKey: "Modified: \(collection.lastModifiedDate.formattedMediumDate)",
              systemImage: "clock",
              backgroundColor: Color.purple.opacity(0.2),
              foregroundColor: .purple
            )
          }
        }
      }
    }
  }
}
