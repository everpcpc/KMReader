//
//  CollectionRowView.swift
//  Komga
//
//  Created by Komga iOS Client
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
          Text(komgaCollection.name)
            .font(.callout)
            .lineLimit(2)
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
                onDeleteRequested: {
                  showDeleteConfirmation = true
                },
                onEditRequested: {
                  showEditSheet = true
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
}
