//
//  CollectionCardView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct CollectionCardView: View {
  let collection: Collection
  let width: CGFloat

  private var thumbnailURL: URL? {
    CollectionService.shared.getCollectionThumbnailURL(id: collection.id)
  }

  var body: some View {
    NavigationLink(value: NavDestination.collectionDetail(collectionId: collection.id)) {
      VStack(alignment: .leading, spacing: 8) {
        ThumbnailImage(url: thumbnailURL, width: width, cornerRadius: 12)

        VStack(alignment: .leading, spacing: 4) {
          Text(collection.name)
            .font(.headline)
            .lineLimit(1)

          Text("\(collection.seriesIds.count) series")
            .font(.caption)
            .foregroundColor(.secondary)

          Text(collection.lastModifiedDate.formatted(date: .abbreviated, time: .omitted))
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .frame(width: width, alignment: .leading)
      }
    }
    .buttonStyle(.plain)
  }
}
