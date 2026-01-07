//
//  CollectionCardView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct CollectionCardView: View {
  @Bindable var komgaCollection: KomgaCollection

  @AppStorage("coverOnlyCards") private var coverOnlyCards: Bool = false
  @State private var showEditSheet = false
  @State private var showDeleteConfirmation = false

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      ThumbnailImage(
        id: komgaCollection.collectionId,
        type: .collection,
        shadowStyle: .platform,
        alignment: .bottom,
        navigationLink: NavDestination.collectionDetail(collectionId: komgaCollection.collectionId)
      ) {
      } menu: {
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
      }

      if !coverOnlyCards {
        VStack(alignment: .leading) {
          Text(komgaCollection.name)
            .lineLimit(1)

          HStack(spacing: 4) {
            Text("\(komgaCollection.seriesIds.count) series")
            Spacer()
          }.foregroundColor(.secondary)
        }.font(.footnote)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .frame(maxHeight: .infinity, alignment: .top)
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
        await MainActor.run {
          ErrorManager.shared.notify(message: String(localized: "notification.collection.deleted"))
        }
      } catch {
        await MainActor.run {
          ErrorManager.shared.alert(error: error)
        }
      }
    }
  }
}
