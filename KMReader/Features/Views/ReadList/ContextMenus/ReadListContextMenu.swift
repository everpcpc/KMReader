//
//  ReadListContextMenu.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftData
import SwiftUI

@MainActor
struct ReadListContextMenu: View {
  @Bindable var komgaReadList: KomgaReadList

  var onActionCompleted: (() -> Void)? = nil
  var onDeleteRequested: (() -> Void)? = nil
  var onEditRequested: (() -> Void)? = nil

  @AppStorage("isAdmin") private var isAdmin: Bool = false
  @AppStorage("isOffline") private var isOffline: Bool = false

  private var readList: ReadList {
    komgaReadList.toReadList()
  }

  var body: some View {
    Group {
      NavigationLink(value: NavDestination.readListDetail(readListId: readList.id)) {
        Label("View Details", systemImage: "info.circle")
      }

      if !isOffline && isAdmin {
        Divider()
        Button {
          onEditRequested?()
        } label: {
          Label("Edit", systemImage: "pencil")
        }
        Divider()
        Button(role: .destructive) {
          onDeleteRequested?()
        } label: {
          Label("Delete", systemImage: "trash")
        }
      }
    }
  }
}
