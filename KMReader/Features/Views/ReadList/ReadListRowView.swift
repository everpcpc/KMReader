//
//  ReadListRowView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct ReadListRowView: View {
  @Bindable var komgaReadList: KomgaReadList

  @State private var showEditSheet = false
  @State private var showDeleteConfirmation = false

  var body: some View {
    HStack(spacing: 12) {
      NavigationLink(value: NavDestination.readListDetail(readListId: komgaReadList.readListId)) {
        ThumbnailImage(id: komgaReadList.readListId, type: .readlist, width: 60)
      }
      .adaptiveButtonStyle(.plain)

      VStack(alignment: .leading, spacing: 6) {
        NavigationLink(value: NavDestination.readListDetail(readListId: komgaReadList.readListId)) {
          Text(komgaReadList.name)
            .font(.callout)
            .lineLimit(2)
        }.adaptiveButtonStyle(.plain)

        HStack {
          VStack(alignment: .leading, spacing: 4) {
            Label("\(komgaReadList.bookIds.count) books", systemImage: "book")
              .font(.footnote)
              .foregroundColor(.secondary)

            Label(
              komgaReadList.lastModifiedDate.formatted(date: .abbreviated, time: .omitted),
              systemImage: "clock"
            )
            .font(.caption)
            .foregroundColor(.secondary)

            if !komgaReadList.summary.isEmpty {
              Text(komgaReadList.summary)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
            }
          }

          Spacer()

          Image(systemName: "ellipsis")
            .hidden()
            .overlay(
              Menu {
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
                .id(komgaReadList.readListId)
              } label: {
                Image(systemName: "ellipsis")
                  .foregroundColor(.secondary)
                  .frame(width: 40, height: 40)
                  .contentShape(Rectangle())
              }.adaptiveButtonStyle(.plain)
            )
        }
      }
    }
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
