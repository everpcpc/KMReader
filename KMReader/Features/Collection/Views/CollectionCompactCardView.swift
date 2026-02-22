//
// CollectionCompactCardView.swift
//
//

import SwiftUI

struct CollectionCompactCardView: View {
  @Bindable var komgaCollection: KomgaCollection
  var coverWidth: CGFloat = 80
  @State private var showEditSheet = false
  @State private var showDeleteConfirmation = false

  var body: some View {
    NavigationLink(
      value: NavDestination.collectionDetail(collectionId: komgaCollection.collectionId)
    ) {
      HStack(alignment: .top, spacing: 10) {
        ThumbnailImage(id: komgaCollection.collectionId, type: .collection, width: coverWidth)
          .frame(width: coverWidth)
          .allowsHitTesting(false)

        VStack(alignment: .leading, spacing: 4) {
          Text(komgaCollection.name)
            .font(.headline)
            .fontWeight(.medium)
            .lineLimit(2)
            .multilineTextAlignment(.leading)

          Text("\(komgaCollection.seriesIds.count) series")
            .font(.footnote)
            .foregroundColor(.secondary)

          Text(komgaCollection.lastModifiedDate.formattedMediumDate)
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
        collectionId: komgaCollection.collectionId,
        menuTitle: komgaCollection.name,
        isPinned: komgaCollection.isPinned,
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
    .sheet(isPresented: $showEditSheet) {
      CollectionEditSheet(collection: komgaCollection.toCollection())
    }
  }

  private func deleteCollection() {
    Task {
      do {
        try await CollectionService.shared.deleteCollection(
          collectionId: komgaCollection.collectionId)
        ErrorManager.shared.notify(message: String(localized: "notification.collection.deleted"))
      } catch {
        ErrorManager.shared.alert(error: error)
      }
    }
  }

  private func togglePinned() {
    let nextPinned = !komgaCollection.isPinned
    Task {
      await DatabaseOperator.shared.setCollectionPinned(
        collectionId: komgaCollection.collectionId,
        instanceId: komgaCollection.instanceId,
        isPinned: nextPinned
      )
      await DatabaseOperator.shared.commit()
    }
  }
}
