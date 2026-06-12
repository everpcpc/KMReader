//
// ReadListCardView.swift
//
//

import SwiftUI

struct ReadListCardView: View {
  let item: ReadListDisplayItem
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
          isPinned: item.isPinned,
          onDeleteRequested: {
            showDeleteConfirmation = true
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
    .alert("Delete Read List", isPresented: $showDeleteConfirmation) {
      Button("Cancel", role: .cancel) {}
      Button("Delete", role: .destructive) {
        deleteReadList()
      }
    } message: {
      Text("Are you sure you want to delete this read list? This action cannot be undone.")
    }
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

  private func deleteReadList() {
    Task {
      do {
        try await ReadListService.deleteReadList(readListId: item.readListId)
        ErrorManager.shared.notify(message: String(localized: "notification.readList.deleted"))
        onMutationCompleted?()
      } catch {
        ErrorManager.shared.alert(error: error)
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
      try? await DatabaseOperator.database().commit()
      onMutationCompleted?()
    }
  }
}
