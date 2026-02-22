//
// CollectionRowView.swift
//
//

import SwiftUI

struct CollectionRowView: View {
  @Bindable var komgaCollection: KomgaCollection

  @State private var showEditSheet = false
  @State private var showDeleteConfirmation = false

  var body: some View {
    HStack(spacing: 12) {
      NavigationLink(
        value: NavDestination.collectionDetail(collectionId: komgaCollection.collectionId)
      ) {
        ThumbnailImage(id: komgaCollection.collectionId, type: .collection, width: 60)
      }
      .adaptiveButtonStyle(.plain)

      VStack(alignment: .leading, spacing: 6) {
        NavigationLink(
          value: NavDestination.collectionDetail(collectionId: komgaCollection.collectionId)
        ) {
          HStack(spacing: 6) {
            Text(komgaCollection.name)
              .font(.callout)
              .lineLimit(2)
            if komgaCollection.isPinned {
              Image(systemName: "pin.fill")
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
          }
        }.adaptiveButtonStyle(.plain)

        HStack {
          VStack(alignment: .leading, spacing: 4) {
            Label("\(komgaCollection.seriesIds.count) series", systemImage: ContentIcon.series)
              .font(.footnote)
              .foregroundColor(.secondary)

            Label(
              komgaCollection.lastModifiedDate.formatted(date: .abbreviated, time: .omitted),
              systemImage: "clock"
            )
            .font(.caption)
            .foregroundColor(.secondary)
          }

          Spacer()

          EllipsisMenuButton {
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
            .id(komgaCollection.collectionId)
          }
        }
      }
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
