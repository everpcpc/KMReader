//
// CollectionDetailContentView.swift
//
//

import SwiftUI

struct CollectionDetailContentView: View {
  let collection: SeriesCollection
  @State private var thumbnailRefreshKey = UUID()

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
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
              thumbnailRefreshKey = UUID()
              ErrorManager.shared.notify(
                message: String(localized: "notification.cover.refreshed"))
            } catch {
              ErrorManager.shared.notify(
                message: String(localized: "notification.cover.refreshFailed"))
            }
          }
        } label: {
          Label(String(localized: "Refresh Cover"), systemImage: "arrow.clockwise")
        }
      }
      .id(thumbnailRefreshKey)

      VStack(alignment: .leading, spacing: 6) {
        DetailTitleView(title: collection.name)

        DetailMetadataRow(
          systemImage: ContentIcon.collection,
          text: Text("\(collection.seriesIds.count) series")
        )
        if collection.ordered {
          DetailMetadataRow(
            systemImage: "arrow.up.arrow.down",
            text: Text("Ordered")
          )
        }
        DetailTimestampsView(
          created: collection.createdDate, lastModified: collection.lastModifiedDate)
      }
    }
  }
}
