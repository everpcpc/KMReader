//
// ReadListItemQueryView.swift
//
//

import SwiftUI

struct ReadListItemQueryView: View {
  let item: ReadListDisplayItem
  var layout: BrowseLayoutMode = .grid
  var onMutationCompleted: (() -> Void)? = nil

  @State private var showDeleteConfirmation = false

  var body: some View {
    NavigationLink(value: NavDestination.readListDetail(readListId: item.readListId)) {
      switch layout {
      case .grid:
        ReadListCardView(
          item: item,
          onMutationCompleted: onMutationCompleted,
          onDeleteRequested: {
            showDeleteConfirmation = true
          }
        )
      case .list:
        ReadListRowView(
          item: item,
          onMutationCompleted: onMutationCompleted,
          onDeleteRequested: {
            showDeleteConfirmation = true
          }
        )
      }
    }
    .adaptiveButtonStyle(.plain)
    .alert("Delete Read List", isPresented: $showDeleteConfirmation) {
      Button("Cancel", role: .cancel) {}
      Button("Delete", role: .destructive) {
        deleteReadList()
      }
    } message: {
      Text("Are you sure you want to delete this read list? This action cannot be undone.")
    }
  }

  private func deleteReadList() {
    Task {
      do {
        try await ReadListService.deleteReadList(readListId: item.readListId)
        ErrorManager.shared.notify(message: String(localized: "notification.readList.deleted"))
        onMutationCompleted?()
      } catch {
        ErrorManager.shared.alert(error: error)
      }
    }
  }
}
