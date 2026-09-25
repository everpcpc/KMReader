//
// ReadListHeroInfoView.swift
//
//

import SwiftUI

/// Title and summary of the read list detail hero. Centered under the
/// compact stacked hero and in the wide rail (via `detailHeroCentered`),
/// leading otherwise.
struct ReadListHeroInfoView: View {
  let readList: ReadList

  @Environment(\.detailHeroCentered) private var heroCentered

  var body: some View {
    VStack(alignment: heroCentered ? .center : .leading, spacing: 6) {
      DetailTitleView(title: readList.name)

      if !readList.summary.isEmpty {
        Text(readList.summary)
          .font(.subheadline)
          .foregroundColor(.secondary)
          .multilineTextAlignment(heroCentered ? .center : .leading)
          .textSelectionIfAvailable()
      }
    }
    .frame(maxWidth: .infinity)
  }
}
