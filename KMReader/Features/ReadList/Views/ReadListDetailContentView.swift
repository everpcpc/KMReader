//
// ReadListDetailContentView.swift
//
//

import SwiftUI

struct ReadListDetailContentView: View {
  let readList: ReadList
  @State private var thumbnailRefreshKey = UUID()

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      ThumbnailImage(
        id: readList.id,
        type: .readlist,
        width: PlatformHelper.detailThumbnailWidth,
        isTransitionSource: false,
        onAction: {}
      ) {
      } menu: {
        Button {
          Task {
            do {
              _ = try await ThumbnailCache.shared.ensureThumbnail(
                id: readList.id,
                type: .readlist,
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
        DetailTitleView(title: readList.name)

        // Summary
        if !readList.summary.isEmpty {
          Text(readList.summary)
            .font(.subheadline)
            .foregroundColor(.secondary)
            .textSelectionIfAvailable()
        }

        // Info rows
        DetailMetadataRow(
          systemImage: ContentIcon.book,
          text: Text("\(readList.bookIds.count) books")
        )
        if readList.ordered {
          DetailMetadataRow(
            systemImage: "arrow.up.arrow.down",
            text: Text("Ordered")
          )
        }
        DetailTimestampsView(
          created: readList.createdDate, lastModified: readList.lastModifiedDate)
      }
    }
  }
}
