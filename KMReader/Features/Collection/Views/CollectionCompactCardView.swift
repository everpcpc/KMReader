//
// CollectionCompactCardView.swift
//
//

import SwiftUI

struct CollectionCompactCardView: View {
  let collection: SeriesCollection

  var body: some View {
    NavigationLink(
      value: NavDestination.collectionDetail(collectionId: collection.id)
    ) {
      HStack {
        ThumbnailImage(id: collection.id, type: .collection, width: 60)

        VStack(alignment: .leading, spacing: 4) {
          Text(collection.name)
            .font(.callout)
            .fontWeight(.medium)
            .lineLimit(2)
            .multilineTextAlignment(.leading)

          Text("\(collection.seriesIds.count) series")
            .font(.footnote)
            .foregroundColor(.secondary)

          Text(collection.lastModifiedDate.formattedMediumDate)
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
