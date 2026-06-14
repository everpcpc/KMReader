//
// CollectionCardView.swift
//
//

import SwiftUI

struct CollectionCardView: View {
  let item: CollectionDisplayItem
  var onMutationCompleted: (() -> Void)? = nil

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
        id: item.collectionId,
        type: .collection,
        shadowStyle: .platform,
        alignment: .bottom,
        navigationLink: NavDestination.collectionDetail(collectionId: item.collectionId),
        preserveAspectRatioOverride: cardTextOverlayMode ? false : nil
      ) {
        if cardTextOverlayMode {
          CardTextOverlay(cornerRadius: 8) {
            overlayTextContent
          }
        }
      } menu: {
        CollectionContextMenu(
          collectionId: item.collectionId,
          menuTitle: item.name,
          isPinned: item.isPinned,
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

      if !cardTextOverlayMode && !coverOnlyCards {
        VStack(alignment: .leading) {
          HStack(spacing: 4) {
            if item.isPinned {
              Image(systemName: "pin.fill")
            }
            Text(item.name)
              .lineLimit(1)
          }

          HStack(spacing: 4) {
            Text("\(item.seriesCount) series")
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
      CollectionEditSheet(collection: item.collection)
    }
  }

  @ViewBuilder
  private var overlayTextContent: some View {
    CardOverlayTextStack(
      title: item.name,
      titleLeadingSystemImage: item.isPinned ? "pin.fill" : nil
    ) {
      HStack(spacing: 4) {
        Text("\(item.seriesCount) series")
      }
    }
  }

  private func deleteCollection() {
    Task {
      do {
        try await CollectionService.deleteCollection(
          collectionId: item.collectionId)
        ErrorManager.shared.notify(message: String(localized: "notification.collection.deleted"))
        onMutationCompleted?()
      } catch {
        ErrorManager.shared.alert(error: error)
      }
    }
  }

  private func togglePinned() {
    let nextPinned = !item.isPinned
    Task {
      try? await DatabaseOperator.database().setCollectionPinned(
        collectionId: item.collectionId,
        instanceId: item.instanceId,
        isPinned: nextPinned
      )
      onMutationCompleted?()
    }
  }
}
