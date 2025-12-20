//
//  CollectionCardView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct CollectionCardView: View {
  let collection: SeriesCollection
  let width: CGFloat
  var onActionCompleted: (() -> Void)? = nil

  @State private var showEditSheet = false
  @State private var showDeleteConfirmation = false

  var body: some View {
    NavigationLink(value: NavDestination.collectionDetail(collectionId: collection.id)) {
      VStack(alignment: .leading, spacing: 8) {
        ThumbnailImage(id: collection.id, type: .collection, width: width, cornerRadius: 12)

        VStack(alignment: .leading, spacing: 4) {
          Text(collection.name)
            .font(.headline)
            .lineLimit(1)

          Text("\(collection.seriesIds.count) series")
            .font(.caption)
            .foregroundColor(.secondary)

          Text(collection.lastModifiedDate.formatted(date: .abbreviated, time: .omitted))
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .frame(width: width, alignment: .leading)
      }
      .frame(maxHeight: .infinity, alignment: .top)
    }
    .adaptiveButtonStyle(.plain)
    .contextMenu {
      CollectionContextMenu(
        collection: collection,
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
      CollectionEditSheet(collection: collection)
        .onDisappear {
          onActionCompleted?()
        }
    }
  }

  private func deleteCollection() {
    Task {
      do {
        try await CollectionService.shared.deleteCollection(collectionId: collection.id)
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
