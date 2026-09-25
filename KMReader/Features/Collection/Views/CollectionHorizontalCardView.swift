//
// CollectionHorizontalCardView.swift
//
//

import SwiftUI

@MainActor
struct CollectionHorizontalCardView: View {
  let item: CollectionDisplayItem
  var coverWidth: CGFloat = 80
  var onChanged: () -> Void = {}
  let onDeleteRequested: () -> Void

  @State private var showEditSheet = false

  var body: some View {
    NavigationLink(
      value: NavDestination.collectionDetail(collectionId: item.collectionId)
    ) {
      HStack(alignment: .center, spacing: 10) {
        ThumbnailImage(
          id: item.collectionId, type: .collection, width: coverWidth, preserveAspectRatioOverride: false
        )
        .frame(width: coverWidth)
        .allowsHitTesting(false)

        VStack(alignment: .leading, spacing: 0) {
          Spacer(minLength: 0)

          Text(item.name)
            .font(.system(LayoutConfig.horizontalCardTitleTextStyle, weight: .medium))
            .lineLimit(2)
            .multilineTextAlignment(.leading)

          Spacer(minLength: 0)

          VStack(alignment: .leading, spacing: 4) {
            Text("\(item.seriesCount) series")
              .font(.system(LayoutConfig.horizontalCardSecondaryTextStyle))
              .foregroundColor(.secondary)

            Text(item.lastModifiedDate.formattedMediumDate)
              .font(.system(LayoutConfig.horizontalCardSecondaryTextStyle))
              .foregroundColor(.secondary)
          }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
      }
      .padding(6)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background {
        RoundedRectangle(cornerRadius: 12)
          .fill(.regularMaterial)
          .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
      }
      .contentShape(Rectangle())
      #if os(iOS)
        .contentShape(.contextMenuPreview, RoundedRectangle(cornerRadius: 12))
      #endif
    }
    .adaptiveButtonStyle(.plain)
    .contextMenu {
      CollectionContextMenu(
        collectionId: item.collectionId,
        menuTitle: item.name,
        isPinned: item.isPinned,
        onDeleteRequested: {
          onDeleteRequested()
        },
        onEditRequested: {
          showEditSheet = true
        },
        onPinToggleRequested: {
          togglePinned()
        }
      )
    }
    .sheet(isPresented: $showEditSheet, onDismiss: onChanged) {
      CollectionEditSheet(collection: item.collection)
    }
  }

  private func togglePinned() {
    let nextPinned = !item.isPinned
    Task {
      do {
        let database = try await DatabaseOperator.database()
        await database.setCollectionPinned(
          collectionId: item.collectionId,
          instanceId: item.instanceId,
          isPinned: nextPinned
        )
        onChanged()
      } catch {
        ErrorManager.shared.alert(error: error)
      }
    }
  }
}
