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

      if !isOffline {
        if current.isAdmin {
          Divider()
          Button {
            onEditRequested?()
          } label: {
            Label("Edit", systemImage: "pencil")
          }
        }

        Divider()
        Button {
          refreshCover()
        } label: {
          Label("Refresh Cover", systemImage: "arrow.clockwise")
        }
      }
    }
  }

  private func refreshCover() {
    Task {
      do {
        try await ThumbnailCache.refreshThumbnail(id: collectionId, type: .collection)
        ErrorManager.shared.notify(message: String(localized: "notification.collection.coverRefreshed"))
      } catch {
        ErrorManager.shared.alert(error: error)
      }
    }
  }
}
