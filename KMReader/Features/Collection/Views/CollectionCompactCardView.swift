//
// CollectionCompactCardView.swift
//
//

import SwiftUI

@MainActor
struct CollectionCompactCardView: View {
  let item: CollectionDisplayItem
  var coverWidth: CGFloat = 80
  var onChanged: () -> Void = {}

  @State private var showEditSheet = false
  @State private var showDeleteConfirmation = false

  var body: some View {
    NavigationLink(
      value: NavDestination.collectionDetail(collectionId: item.collectionId)
    ) {
      HStack(alignment: .top, spacing: 10) {
        ThumbnailImage(id: item.collectionId, type: .collection, width: coverWidth)
          .frame(width: coverWidth)
          .allowsHitTesting(false)

        VStack(alignment: .leading, spacing: 4) {
          Text(item.name)
            .font(.headline)
            .fontWeight(.medium)
            .lineLimit(2)
            .multilineTextAlignment(.leading)

          Text("\(item.seriesCount) series")
            .font(.footnote)
            .foregroundColor(.secondary)

          Text(item.lastModifiedDate.formattedMediumDate)
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }
      .padding(8)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background {
        RoundedRectangle(cornerRadius: 12)
          .fill(.regularMaterial)
          .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
      }
      .contentShape(Rectangle())
      #if os(iOS)
        .contentShape(.contextMenuPreview, RoundedRectangle(cornerRadius: 12))
      #endif
    }
    .adaptiveButtonStyle(.plain)
    .contextMenu {
      CollectionContextMenu(
        collectionId: item.collectionId,
        menuTitle: item.name,
        isPinned: item.isPinned,
        onDeleteRequested: {
          showDeleteConfirmation = true
        },
        onEditRequested: {
          showEditSheet = true
        },
        onPinToggleRequested: {
          togglePinned()
        }
      )
    }
    .alert("Delete Collection", isPresented: $showDeleteConfirmation) {
      Button("Cancel", role: .cancel) {}
      Button("Delete", role: .destructive) {
        deleteCollection()
      }
    } message: {
      Text("Are you sure you want to delete this collection? This action cannot be undone.")
    }
    .sheet(isPresented: $showEditSheet, onDismiss: onChanged) {
      CollectionEditSheet(collection: item.collection)
    }
  }

  private func deleteCollection() {
    Task {
      do {
        try await CollectionService.deleteCollection(
          collectionId: item.collectionId)
        ErrorManager.shared.notify(message: String(localized: "notification.collection.deleted"))
        onChanged()
      } catch {
        ErrorManager.shared.alert(error: error)
      }
    }
  }

  private func togglePinned() {
    let nextPinned = !item.isPinned
    Task {
      do {
        let database = try await DatabaseOperator.database()
        await database.setCollectionPinned(
          collectionId: item.collectionId,
          instanceId: item.instanceId,
          isPinned: nextPinned
        )
        onChanged()
      } catch {
        ErrorManager.shared.alert(error: error)
      }
    }
  }
}
