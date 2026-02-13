//
//  ReadListCardView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct ReadListCardView: View {
  @Bindable var komgaReadList: KomgaReadList

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
        id: komgaReadList.readListId,
        type: .readlist,
        shadowStyle: .platform,
        alignment: .bottom,
        navigationLink: NavDestination.readListDetail(readListId: komgaReadList.readListId),
        preserveAspectRatioOverride: cardTextOverlayMode ? false : nil
      ) {
        if cardTextOverlayMode {
          CardTextOverlay(cornerRadius: 8) {
            overlayTextContent
          }
        }
      } menu: {
        ReadListContextMenu(
          readListId: komgaReadList.readListId,
          menuTitle: komgaReadList.name,
          downloadStatus: komgaReadList.downloadStatus,
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
          Text(komgaReadList.name)
            .lineLimit(1)

          HStack(spacing: 4) {
            Text("\(komgaReadList.bookIds.count) books")
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
      ReadListEditSheet(readList: komgaReadList.toReadList())
    }
  }

  @ViewBuilder
  private var overlayTextContent: some View {
    CardOverlayTextStack(title: komgaReadList.name) {
      HStack(spacing: 4) {
        Text("\(komgaReadList.bookIds.count) books")
        Spacer()
      }
    }
  }

  private func deleteReadList() {
    Task {
      do {
        try await ReadListService.shared.deleteReadList(readListId: komgaReadList.readListId)
        ErrorManager.shared.notify(message: String(localized: "notification.readList.deleted"))
      } catch {
        ErrorManager.shared.alert(error: error)
      }
    }
  }
}
