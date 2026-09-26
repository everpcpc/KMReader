//
// ReadListDetailContentView.swift
//
//

import SwiftUI

struct ReadListDetailContentView<Actions: View>: View {
  let readList: ReadList
  @ViewBuilder let actions: Actions

  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  init(
    readList: ReadList,
    @ViewBuilder actions: () -> Actions
  ) {
    self.readList = readList
    self.actions = actions()
  }

  private var isCompactLayout: Bool {
    horizontalSizeClass == .compact
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      DetailHeroView(
        id: readList.id,
        type: .readlist,
        contentBlurRadius: 0
      ) {
        ReadListHeroInfoView(readList: readList)
      }

      DetailActionCard {
        ReadListBookCountView(readList: readList)

        actions
      }
      .frame(maxWidth: isCompactLayout ? 480 : .infinity)
      .frame(maxWidth: .infinity, alignment: isCompactLayout ? .center : .leading)

      DetailTimestampsView(
        created: readList.createdDate, lastModified: readList.lastModifiedDate
      )
      .frame(maxWidth: .infinity, alignment: isCompactLayout ? .center : .leading)
    }
    .environment(\.detailHeroCentered, isCompactLayout)
  }
}
