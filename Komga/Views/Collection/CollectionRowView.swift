//
//  CollectionRowView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct CollectionRowView: View {
  let collection: Collection

  private var thumbnailURL: URL? {
    CollectionService.shared.getCollectionThumbnailURL(id: collection.id)
  }

  var body: some View {
    NavigationLink(value: NavDestination.collectionDetail(collectionId: collection.id)) {
      HStack(spacing: 12) {
        ThumbnailImage(url: thumbnailURL, width: 70, cornerRadius: 10)

        VStack(alignment: .leading, spacing: 6) {
          Text(collection.name)
            .font(.callout)
          Text("\(collection.seriesIds.count) series")
            .font(.footnote)
            .foregroundColor(.secondary)

          HStack(spacing: 12) {
            Label {
              Text(collection.createdDate.formatted(date: .abbreviated, time: .omitted))
            } icon: {
              Image(systemName: "calendar")
            }
            .font(.caption)
            .foregroundColor(.secondary)

            Label {
              Text(collection.lastModifiedDate.formatted(date: .abbreviated, time: .omitted))
            } icon: {
              Image(systemName: "clock")
            }
            .font(.caption)
            .foregroundColor(.secondary)
          }
        }

        Spacer()

        Image(systemName: "chevron.right")
          .foregroundColor(.secondary)
      }
    }
    .buttonStyle(.plain)
  }
}
