//
// ReadListQueryItemView.swift
//
//

import SQLiteData
import SwiftUI

/// Wrapper view that accepts only readListId and fetches the local record reactively.
struct ReadListQueryItemView: View {
  let readListId: String
  var layout: BrowseLayoutMode = .grid

  @FetchAll private var komgaReadLists: [KomgaReadListRecord]
  @FetchAll private var readListLocalStateList: [KomgaReadListLocalStateRecord]

  init(
    readListId: String,
    layout: BrowseLayoutMode = .grid
  ) {
    self.readListId = readListId
    self.layout = layout

    let instanceId = AppConfig.current.instanceId
    _komgaReadLists = FetchAll(
      KomgaReadListRecord.where { $0.instanceId.eq(instanceId) && $0.readListId.eq(readListId) }
    )
    _readListLocalStateList = FetchAll(
      KomgaReadListLocalStateRecord.where { $0.instanceId.eq(instanceId) && $0.readListId.eq(readListId) }
    )
  }

  private var komgaReadList: KomgaReadList? {
    guard let record = komgaReadLists.first else { return nil }
    return record.toKomgaReadList(localState: readListLocalStateList.first)
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
