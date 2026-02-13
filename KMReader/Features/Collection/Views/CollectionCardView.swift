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
  @AppStorage("cardTextOverlayMode") private var cardTextOverlayMode: Bool = false
  @State private var showEditSheet = false
  @State private var showDeleteConfirmation = false

  private var contentSpacing: CGFloat {
    cardTextOverlayMode ? 0 : 12
  }

  var body: some View {
    VStack(alignment: .leading, spacing: contentSpacing) {
      ThumbnailImage(
        id: komgaCollection.collectionId,
        type: .collection,
        shadowStyle: .platform,
        alignment: .bottom,
        navigationLink: NavDestination.collectionDetail(collectionId: komgaCollection.collectionId),
        preserveAspectRatioOverride: cardTextOverlayMode ? false : nil
      ) {
        if cardTextOverlayMode {
          CardTextOverlay(cornerRadius: 8) {
            overlayTextContent
          }
        }
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

      if !cardTextOverlayMode && !coverOnlyCards {
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

  @ViewBuilder
  private var overlayTextContent: some View {
    CardOverlayTextStack(title: komgaCollection.name) {
      HStack(spacing: 4) {
        Text("\(komgaCollection.seriesIds.count) series")
        Spacer()
      }
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
