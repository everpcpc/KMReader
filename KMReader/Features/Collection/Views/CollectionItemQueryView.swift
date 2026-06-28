//
// CollectionItemQueryView.swift
//
//

import SwiftUI

struct CollectionItemQueryView: View {
  let item: CollectionDisplayItem
  var layout: BrowseLayoutMode = .grid
  var onMutationCompleted: (() -> Void)? = nil

  @State private var showDeleteConfirmation = false

  var body: some View {
    NavigationLink(value: NavDestination.collectionDetail(collectionId: item.collectionId)) {
      switch layout {
      case .grid:
        CollectionCardView(
          item: item,
          onMutationCompleted: onMutationCompleted,
          onDeleteRequested: {
            showDeleteConfirmation = true
          }
        )
      case .list:
        CollectionRowView(
          item: item,
          onMutationCompleted: onMutationCompleted,
          onDeleteRequested: {
            showDeleteConfirmation = true
          }
        )
      }
    }
    .adaptiveButtonStyle(.plain)
    .alert("Delete Collection", isPresented: $showDeleteConfirmation) {
      Button("Cancel", role: .cancel) {}
      Button("Delete", role: .destructive) {
        deleteCollection()
      }
    } message: {
      Text("Are you sure you want to delete this collection? This action cannot be undone.")
    }
  }

  private func deleteCollection() {
    Task {
      do {
        try await CollectionService.deleteCollection(collectionId: item.collectionId)
        ErrorManager.shared.notify(message: String(localized: "notification.collection.deleted"))
        onMutationCompleted?()
      } catch {
        ErrorManager.shared.alert(error: error)
      }
    }
  }
}
