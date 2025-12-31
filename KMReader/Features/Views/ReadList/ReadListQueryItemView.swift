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
  var layout: BrowseLayoutMode = .grid
  var onActionCompleted: (() -> Void)?

  @Query private var komgaReadLists: [KomgaReadList]

  init(
    readListId: String,
    layout: BrowseLayoutMode = .grid,
    onActionCompleted: (() -> Void)? = nil
  ) {
    self.readListId = readListId
    self.layout = layout
    self.onActionCompleted = onActionCompleted

    let instanceId = AppConfig.currentInstanceId
    let compositeId = "\(instanceId)_\(readListId)"
    _komgaReadLists = Query(filter: #Predicate<KomgaReadList> { $0.id == compositeId })
  }

  private var komgaReadList: KomgaReadList? {
    komgaReadLists.first
  }

  var body: some View {
    if let readList = komgaReadList {
      switch layout {
      case .grid:
        ReadListCardView(
          komgaReadList: readList,
          onActionCompleted: onActionCompleted
        )
      case .list:
        ReadListRowView(
          komgaReadList: readList,
          onActionCompleted: onActionCompleted
        )
      }
    } else {
      CardPlaceholder(layout: layout)
    }
  }
}
