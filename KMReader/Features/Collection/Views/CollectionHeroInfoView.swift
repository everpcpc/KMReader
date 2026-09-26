//
// CollectionHeroInfoView.swift
//
//

import SwiftUI

/// Title of the collection detail hero.
struct CollectionHeroInfoView: View {
  let collection: SeriesCollection

  @Environment(\.detailHeroCentered) private var heroCentered

  var body: some View {
    VStack(alignment: heroCentered ? .center : .leading, spacing: 6) {
      DetailTitleView(title: collection.name)
    }
    .frame(maxWidth: .infinity, alignment: heroCentered ? .center : .leading)
  }
}
