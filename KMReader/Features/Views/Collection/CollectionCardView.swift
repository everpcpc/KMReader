//
//  CollectionCardView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct CollectionCardView: View {
  @Bindable var komgaCollection: KomgaCollection
  let width: CGFloat
  var onActionCompleted: (() -> Void)? = nil

  @State private var showEditSheet = false
  @State private var showDeleteConfirmation = false

  var body: some View {
    CardView {
      VStack(alignment: .leading, spacing: 8) {
        ThumbnailImage(id: komgaCollection.collectionId, type: .collection, width: width - 8)

        VStack(alignment: .leading, spacing: 4) {
          Text(komgaCollection.name)
            .font(.headline)
            .lineLimit(1)

          Text("\(komgaCollection.seriesIds.count) series")
            .font(.caption)
            .foregroundColor(.secondary)

          Text(komgaCollection.lastModifiedDate.formatted(date: .abbreviated, time: .omitted))
            .font(.caption)
            .foregroundColor(.secondary)
        }
      }
    }
    .frame(width: width, alignment: .leading)
    .adaptiveButtonStyle(.plain)
    .frame(maxHeight: .infinity, alignment: .top)
    .contentShape(Rectangle())
    .contextMenu {
      CollectionContextMenu(
        collection: komgaCollection.toCollection(),
        onActionCompleted: onActionCompleted,
        onDeleteRequested: {
          showDeleteConfirmation = true
        },
        onEditRequested: {
          showEditSheet = true
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
        .onDisappear {
          onActionCompleted?()
        }
    }
  }

  private func deleteCollection() {
    Task {
      do {
        try await CollectionService.shared.deleteCollection(
          collectionId: komgaCollection.collectionId)
        await MainActor.run {
          ErrorManager.shared.notify(message: String(localized: "notification.collection.deleted"))
          onActionCompleted?()
        }
      } catch {
        await MainActor.run {
          ErrorManager.shared.alert(error: error)
        }
      }
    }
  }
}
