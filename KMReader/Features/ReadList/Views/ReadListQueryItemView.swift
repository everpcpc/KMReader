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

  @Query private var komgaReadLists: [KomgaReadList]

  init(
    readListId: String,
    layout: BrowseLayoutMode = .grid
  ) {
    self.readListId = readListId
    self.layout = layout

    let compositeId = CompositeID.generate(id: readListId)
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
          komgaReadList: readList
        )
      case .list:
        ReadListRowView(
          komgaReadList: readList
        )
      }
    } else {
      CardPlaceholder(layout: layout, kind: .readList)
    }
  }
}
