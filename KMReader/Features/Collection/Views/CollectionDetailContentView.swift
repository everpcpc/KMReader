//
// CollectionDetailContentView.swift
//
//

import SwiftUI

struct CollectionDetailContentView: View {
  let collection: SeriesCollection

  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  init(collection: SeriesCollection) {
    self.collection = collection
  }

  private var isCompactLayout: Bool {
    horizontalSizeClass == .compact
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      DetailHeroView(
        id: collection.id,
        type: .collection,
        contentBlurRadius: 0
      ) {
        CollectionHeroInfoView(collection: collection)
      }

      DetailActionCard {
        CollectionBookCountView(collection: collection)
      }
      .frame(maxWidth: isCompactLayout ? 480 : .infinity)
      .frame(maxWidth: .infinity, alignment: isCompactLayout ? .center : .leading)

      DetailTimestampsView(
        created: collection.createdDate, lastModified: collection.lastModifiedDate
      )
      .frame(maxWidth: .infinity, alignment: isCompactLayout ? .center : .leading)
    }
    .environment(\.detailHeroCentered, isCompactLayout)
  }
}
