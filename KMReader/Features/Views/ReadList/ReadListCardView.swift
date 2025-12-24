//
//  ReadListCardView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct ReadListCardView: View {
  @Bindable var komgaReadList: KomgaReadList
  let width: CGFloat
  var onActionCompleted: (() -> Void)? = nil

  @State private var showEditSheet = false
  @State private var showDeleteConfirmation = false

  private var bookCountText: String {
    let count = komgaReadList.bookIds.count
    return count == 1 ? "1 book" : "\(count) books"
  }

  var body: some View {
    CardView {
      VStack(alignment: .leading, spacing: 8) {
        ThumbnailImage(id: komgaReadList.readListId, type: .readlist, width: width - 8)

        VStack(alignment: .leading, spacing: 4) {
          Text(komgaReadList.name)
            .font(.headline)
            .lineLimit(1)

          Text(bookCountText)
            .font(.caption)
            .foregroundColor(.secondary)

          if !komgaReadList.summary.isEmpty {
            Text(komgaReadList.summary)
              .font(.caption)
              .foregroundColor(.secondary)
              .lineLimit(2)
          }
        }
      }
    }
    .frame(width: width, alignment: .leading)
    .adaptiveButtonStyle(.plain)
    .frame(maxHeight: .infinity, alignment: .top)
    .contentShape(Rectangle())
    .contextMenu {
      ReadListContextMenu(
        readList: komgaReadList.toReadList(),
        onActionCompleted: onActionCompleted,
        onDeleteRequested: {
          showDeleteConfirmation = true
        },
        onEditRequested: {
          showEditSheet = true
        }
      )
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
        .onDisappear {
          onActionCompleted?()
        }
    }
  }

  private func deleteReadList() {
    Task {
      do {
        try await ReadListService.shared.deleteReadList(readListId: komgaReadList.readListId)
        await MainActor.run {
          ErrorManager.shared.notify(message: String(localized: "notification.readList.deleted"))
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
