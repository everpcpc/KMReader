//
// CollectionHeroInfoView.swift
//
//

import SwiftUI

/// Title of the collection detail hero. Centered under the compact stacked
/// hero and in the wide rail (via `detailHeroCentered`), leading otherwise.
struct CollectionHeroInfoView: View {
  let collection: SeriesCollection

  @Environment(\.detailHeroCentered) private var heroCentered

  var body: some View {
    VStack(alignment: heroCentered ? .center : .leading, spacing: 6) {
      DetailTitleView(title: collection.name)
    }
    .frame(maxWidth: .infinity)
  }
}
