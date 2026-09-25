//
// ReadListDetailContentView.swift
//
//

import SwiftUI

struct ReadListDetailContentView<Actions: View>: View {
  let readList: ReadList
  /// iPad's narrow single-column fallback forces the compact centered hero
  /// and caps the action card instead of stretching both across the column.
  let forceCompactHero: Bool
  @ViewBuilder let actions: Actions

  init(
    readList: ReadList,
    forceCompactHero: Bool = false,
    @ViewBuilder actions: () -> Actions
  ) {
    self.readList = readList
    self.forceCompactHero = forceCompactHero
    self.actions = actions()
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      DetailHeroView(
        id: readList.id,
        type: .readlist,
        contentBlurRadius: 0,
        forceCentered: forceCompactHero
      ) {
        ReadListHeroInfoView(readList: readList)
      }

      DetailActionCard {
        ReadListBookCountView(readList: readList)

        actions
      }
      .environment(\.detailHeroCentered, forceCompactHero)
      .frame(maxWidth: forceCompactHero ? 480 : .infinity)
      .frame(maxWidth: .infinity, alignment: forceCompactHero ? .center : .leading)

      DetailTimestampsView(
        created: readList.createdDate, lastModified: readList.lastModifiedDate
      )
      .frame(maxWidth: .infinity, alignment: forceCompactHero ? .center : .leading)
    }
  }
}
