//
//  CollectionCompactCardView.swift
//  KMReader
//
//  Created by Komga iOS Client
//

import SwiftUI

struct CollectionCompactCardView: View {
  @Bindable var komgaCollection: KomgaCollection

  var body: some View {
    NavigationLink(
      value: NavDestination.collectionDetail(collectionId: komgaCollection.collectionId)
    ) {
      HStack {
        ThumbnailImage(id: komgaCollection.collectionId, type: .collection, width: 60)

        VStack(alignment: .leading, spacing: 4) {
          Text(komgaCollection.name)
            .font(.callout)
            .fontWeight(.medium)
            .lineLimit(2)
            .multilineTextAlignment(.leading)

          Text("\(komgaCollection.seriesIds.count) series")
            .font(.footnote)
            .foregroundColor(.secondary)

          Text(komgaCollection.lastModifiedDate.formattedMediumDate)
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .frame(maxWidth: 320, alignment: .leading)
      }
      .padding(6)
      .background {
        RoundedRectangle(cornerRadius: 12)
          .fill(.regularMaterial)
          .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
      }
    }
    .adaptiveButtonStyle(.plain)
  }
}
