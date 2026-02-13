//
//  ReadListDetailContentView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct ReadListDetailContentView: View {
  let readList: ReadList
  @State private var thumbnailRefreshKey = UUID()

  var body: some View {
    VStack(alignment: .leading) {
      Text(readList.name)
        .font(.title2)

      HStack(alignment: .top) {
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

        VStack(alignment: .leading) {
          // Summary
          if !readList.summary.isEmpty {
            Text(readList.summary)
              .font(.subheadline)
              .foregroundColor(.secondary)
              .padding(.top, 4)
          }

          // Info chips
          VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
              InfoChip(
                labelKey: "\(readList.bookIds.count) books",
                systemImage: ContentIcon.book,
                backgroundColor: Color.blue.opacity(0.2),
                foregroundColor: .blue
              )
              if readList.ordered {
                InfoChip(
                  labelKey: "Ordered",
                  systemImage: "arrow.up.arrow.down",
                  backgroundColor: Color.cyan.opacity(0.2),
                  foregroundColor: .cyan
                )
              }
            }
            InfoChip(
              labelKey: "Created: \(readList.createdDate.formattedMediumDate)",
              systemImage: "calendar.badge.plus",
              backgroundColor: Color.blue.opacity(0.2),
              foregroundColor: .blue
            )
            InfoChip(
              labelKey: "Modified: \(readList.lastModifiedDate.formattedMediumDate)",
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
