//
//  CollectionContextMenu.swift
//  Komga
//
//  Created by Komga iOS Client
//

import Foundation
import SwiftUI

@MainActor
struct CollectionContextMenu: View {
  let collection: SeriesCollection
  var onActionCompleted: (() -> Void)? = nil
  var onDeleteRequested: (() -> Void)? = nil
  var onEditRequested: (() -> Void)? = nil
  @AppStorage("isAdmin") private var isAdmin: Bool = false
  @AppStorage("isOffline") private var isOffline: Bool = false

  var body: some View {
    Group {
      NavigationLink(value: NavDestination.collectionDetail(collectionId: collection.id)) {
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
