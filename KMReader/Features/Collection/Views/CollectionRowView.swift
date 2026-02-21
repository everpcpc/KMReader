//
// CollectionRowView.swift
//
//

import SwiftUI

struct CollectionRowView: View {
  let collection: SeriesCollection

  @State private var showEditSheet = false
  @State private var showDeleteConfirmation = false

  var body: some View {
    HStack(spacing: 12) {
      NavigationLink(
        value: NavDestination.collectionDetail(collectionId: collection.id)
      ) {
        ThumbnailImage(id: collection.id, type: .collection, width: 60)
      }
      .adaptiveButtonStyle(.plain)

      VStack(alignment: .leading, spacing: 6) {
        NavigationLink(
          value: NavDestination.collectionDetail(collectionId: collection.id)
        ) {
          Text(collection.name)
            .font(.callout)
            .lineLimit(2)
        }.adaptiveButtonStyle(.plain)

        HStack {
          VStack(alignment: .leading, spacing: 4) {
            Label("\(collection.seriesIds.count) series", systemImage: ContentIcon.series)
              .font(.footnote)
              .foregroundColor(.secondary)

            Label(
              collection.lastModifiedDate.formatted(date: .abbreviated, time: .omitted),
              systemImage: "clock"
            )
            .font(.caption)
            .foregroundColor(.secondary)
          }

          Spacer()

          EllipsisMenuButton {
            CollectionContextMenu(
              collectionId: collection.id,
              menuTitle: collection.name,
              onDeleteRequested: {
                showDeleteConfirmation = true
              },
              onEditRequested: {
                showEditSheet = true
              }
            )
            .id(collection.id)
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
      CollectionEditSheet(collection: collection)
    }
  }

  private func deleteCollection() {
    Task {
      do {
        try await CollectionService.shared.deleteCollection(
          collectionId: collection.id)
        ErrorManager.shared.notify(message: String(localized: "notification.collection.deleted"))
      } catch {
        ErrorManager.shared.alert(error: error)
      }
    }
  }
}
