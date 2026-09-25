//
// CollectionDetailContentView.swift
//
//

import SwiftUI

struct CollectionDetailContentView: View {
  let collection: SeriesCollection
  /// iPad's narrow single-column fallback forces the compact centered hero
  /// and caps the action card instead of stretching both across the column.
  let forceCompactHero: Bool

  init(collection: SeriesCollection, forceCompactHero: Bool = false) {
    self.collection = collection
    self.forceCompactHero = forceCompactHero
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      DetailHeroView(
        id: collection.id,
        type: .collection,
        contentBlurRadius: 0,
        forceCentered: forceCompactHero
      ) {
        CollectionHeroInfoView(collection: collection)
      }

      DetailActionCard {
        CollectionBookCountView(collection: collection)
      }
      .environment(\.detailHeroCentered, forceCompactHero)
      .frame(maxWidth: forceCompactHero ? 480 : .infinity)
      .frame(maxWidth: .infinity, alignment: forceCompactHero ? .center : .leading)

      DetailTimestampsView(
        created: collection.createdDate, lastModified: collection.lastModifiedDate
      )
      .frame(maxWidth: .infinity, alignment: forceCompactHero ? .center : .leading)
    }
  }
}
