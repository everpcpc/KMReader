//
//  CollectionContextMenu.swift
//  Komga
//
//  Created by Komga iOS Client
//

import Foundation
import SwiftUI

struct CollectionContextMenu: View {
  let collectionId: String
  let menuTitle: String
  var onDeleteRequested: (() -> Void)? = nil
  var onEditRequested: (() -> Void)? = nil
  @AppStorage("currentAccount") private var current: Current = .init()
  @AppStorage("isOffline") private var isOffline: Bool = false

  var body: some View {
    Group {
      Button(action: {}) {
        Text(menuTitle.isEmpty ? "Untitled" : menuTitle)
          .font(.footnote)
          .foregroundStyle(.secondary)
          .lineLimit(2)
      }
      .disabled(true)
      Divider()

      NavigationLink(value: NavDestination.collectionDetail(collectionId: collectionId)) {
        Label("View Details", systemImage: "info.circle")
      }

      if !isOffline && current.isAdmin {
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
