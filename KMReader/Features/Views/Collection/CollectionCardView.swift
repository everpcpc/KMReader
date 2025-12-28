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

  @AppStorage("coverOnlyCards") private var coverOnlyCards: Bool = false
  @State private var showEditSheet = false
  @State private var showDeleteConfirmation = false

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      NavigationLink(
        value: NavDestination.collectionDetail(collectionId: komgaCollection.collectionId)
      ) {
        ThumbnailImage(
          id: komgaCollection.collectionId, type: .collection, shadowStyle: .platform, width: width,
          alignment: .bottom
        )
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
      }
      .focusPadding()
      .adaptiveButtonStyle(.plain)

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
    .frame(width: width, alignment: .leading)
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
