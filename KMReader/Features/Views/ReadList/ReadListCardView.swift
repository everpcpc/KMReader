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
  @State private var showEditSheet = false
  @State private var showDeleteConfirmation = false

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      ThumbnailImage(
        id: komgaReadList.readListId,
        type: .readlist,
        shadowStyle: .platform,
        alignment: .bottom,
        navigationLink: NavDestination.readListDetail(readListId: komgaReadList.readListId)
      ) {
      } menu: {
        ReadListContextMenu(
          komgaReadList: komgaReadList,
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

  private func deleteReadList() {
    Task {
      do {
        try await ReadListService.shared.deleteReadList(readListId: komgaReadList.readListId)
        await MainActor.run {
          ErrorManager.shared.notify(message: String(localized: "notification.readList.deleted"))
        }
      } catch {
        await MainActor.run {
          ErrorManager.shared.alert(error: error)
        }
      }
    }
  }
}
