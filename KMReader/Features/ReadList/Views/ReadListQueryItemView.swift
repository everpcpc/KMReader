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

  @FetchAll private var readListRecords: [KomgaReadListRecord]
  @FetchAll private var readListLocalStateList: [KomgaReadListLocalStateRecord]

  init(
    readListId: String,
    layout: BrowseLayoutMode = .grid
  ) {
    self.readListId = readListId
    self.layout = layout

    let instanceId = AppConfig.current.instanceId
    _readListRecords = FetchAll(
      KomgaReadListRecord.where { $0.instanceId.eq(instanceId) && $0.readListId.eq(readListId) }
    )
    _readListLocalStateList = FetchAll(
      KomgaReadListLocalStateRecord.where { $0.instanceId.eq(instanceId) && $0.readListId.eq(readListId) }
    )
  }

  private var readList: ReadList? {
    readListRecords.first?.toReadList()
  }

  private var localState: KomgaReadListLocalStateRecord? {
    readListLocalStateList.first
  }

  var body: some View {
    if let readList = readList {
      switch layout {
      case .grid:
        ReadListCardView(
          readList: readList,
          localState: localState
        )
      case .list:
        ReadListRowView(
          readList: readList,
          localState: localState
        )
      }
    } else {
      CardPlaceholder(layout: layout, kind: .readList)
    }
  }
}
