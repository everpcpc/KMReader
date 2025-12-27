//
//  ReadListQueryItemView.swift
//  KMReader
//
//  Created by Komga iOS Client
//

import SwiftData
import SwiftUI

/// Wrapper view that accepts only readListId and uses @Query to fetch the read list reactively.
struct ReadListQueryItemView: View {
  let readListId: String
  var width: CGFloat?
  var layout: BrowseLayoutMode = .grid
  var onActionCompleted: (() -> Void)?

  @AppStorage("dashboardCardWidth") private var dashboardCardWidth: Double = Double(
    PlatformHelper.defaultDashboardCardWidth)
  @Query private var komgaReadLists: [KomgaReadList]

  init(
    readListId: String,
    width: CGFloat? = nil,
    layout: BrowseLayoutMode = .grid,
    onActionCompleted: (() -> Void)? = nil
  ) {
    self.readListId = readListId
    self.width = width
    self.layout = layout
    self.onActionCompleted = onActionCompleted

    let instanceId = AppConfig.currentInstanceId
    let compositeId = "\(instanceId)_\(readListId)"
    _komgaReadLists = Query(filter: #Predicate<KomgaReadList> { $0.id == compositeId })
  }

  private var komgaReadList: KomgaReadList? {
    komgaReadLists.first
  }

  private var cardWidth: CGFloat {
    width ?? CGFloat(dashboardCardWidth)
  }

  var body: some View {
    if let readList = komgaReadList {
      switch layout {
      case .grid:
        ReadListCardView(
          komgaReadList: readList,
          width: cardWidth,
          onActionCompleted: onActionCompleted
        )
      case .list:
        ReadListRowView(
          komgaReadList: readList,
          onActionCompleted: onActionCompleted
        )
      }
    }
  }
}
