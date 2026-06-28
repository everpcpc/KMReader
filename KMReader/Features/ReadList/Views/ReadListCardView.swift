//
// ReadListCardView.swift
//
//

import SwiftUI

struct ReadListCardView: View {
  let item: ReadListDisplayItem
  var onMutationCompleted: (() -> Void)? = nil
  let onDeleteRequested: () -> Void

  @AppStorage("coverOnlyCards") private var coverOnlyCards: Bool = false
  @AppStorage("cardTextOverlayMode") private var cardTextOverlayMode: Bool = false
  @State private var showEditSheet = false

  private var contentSpacing: CGFloat {
    cardTextOverlayMode ? 0 : 12
  }

  var body: some View {
    VStack(alignment: .leading, spacing: contentSpacing) {
      ThumbnailImage(
        id: item.readListId,
        type: .readlist,
        shadowStyle: .platform,
        alignment: .bottom,
        navigationLink: NavDestination.readListDetail(readListId: item.readListId),
        preserveAspectRatioOverride: cardTextOverlayMode ? false : nil
      ) {
        if cardTextOverlayMode {
          CardTextOverlay(cornerRadius: 8) {
            overlayTextContent
          }
        }
      } menu: {
        ReadListContextMenu(
          readListId: item.readListId,
          menuTitle: item.name,
          downloadStatus: item.downloadStatus,
          offlinePolicy: item.offlinePolicy,
          offlinePolicyLimit: item.offlinePolicyLimit,
          isPinned: item.isPinned,
          onDeleteRequested: {
            onDeleteRequested()
          },
          onEditRequested: {
            showEditSheet = true
          },
          onPinToggleRequested: {
            togglePinned()
          },
          onMutationCompleted: onMutationCompleted
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
            Text("\(item.bookCount) books")
            Spacer()
          }.foregroundColor(.secondary)
        }.font(.footnote)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .frame(maxHeight: .infinity, alignment: .top)
    .sheet(isPresented: $showEditSheet) {
      ReadListEditSheet(readList: item.readList)
    }
  }

  @ViewBuilder
  private var overlayTextContent: some View {
    CardOverlayTextStack(
      title: item.name,
      titleLeadingSystemImage: item.isPinned ? "pin.fill" : nil
    ) {
      HStack(spacing: 4) {
        Text("\(item.bookCount) books")
      }
    }
  }

  private func togglePinned() {
    let nextPinned = !item.isPinned
    Task {
      try? await DatabaseOperator.database().setReadListPinned(
        readListId: item.readListId,
        instanceId: item.instanceId,
        isPinned: nextPinned
      )
      onMutationCompleted?()
    }
  }
}
