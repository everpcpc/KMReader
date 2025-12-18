//
//  CollectionRowView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct CollectionRowView: View {
  let collection: KomgaCollection
  var onActionCompleted: (() -> Void)? = nil

  @State private var showEditSheet = false
  @State private var showDeleteConfirmation = false

  var body: some View {
    NavigationLink(value: NavDestination.collectionDetail(collectionId: collection.id)) {
      HStack(spacing: 12) {
        ThumbnailImage(id: collection.id, type: .collection, width: 70, cornerRadius: 10)

        VStack(alignment: .leading, spacing: 6) {
          Text(collection.name)
            .font(.callout)
          Text("\(collection.seriesIds.count) series")
            .font(.footnote)
            .foregroundColor(.secondary)

          HStack(spacing: 12) {
            Label {
              Text(collection.createdDate.formatted(date: .abbreviated, time: .omitted))
            } icon: {
              Image(systemName: "calendar")
            }
            .font(.caption)
            .foregroundColor(.secondary)

            Label {
              Text(collection.lastModifiedDate.formatted(date: .abbreviated, time: .omitted))
            } icon: {
              Image(systemName: "clock")
            }
            .font(.caption)
            .foregroundColor(.secondary)
          }
        }

        Spacer()

        Image(systemName: "chevron.right")
          .foregroundColor(.secondary)
      }
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
