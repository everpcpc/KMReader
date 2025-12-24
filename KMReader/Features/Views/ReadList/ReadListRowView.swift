//
//  ReadListRowView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct ReadListRowView: View {
  @Bindable var komgaReadList: KomgaReadList
  var onActionCompleted: (() -> Void)? = nil

  @State private var showEditSheet = false
  @State private var showDeleteConfirmation = false

  var body: some View {
    CardView {
      HStack(spacing: 12) {
        ThumbnailImage(id: komgaReadList.readListId, type: .readlist, width: 60)

        VStack(alignment: .leading, spacing: 6) {
          Text(komgaReadList.name)
            .font(.callout)

          Label {
            Text("\(komgaReadList.bookIds.count) book")
          } icon: {
            Image(systemName: "book")
          }
          .font(.footnote)
          .foregroundColor(.secondary)

          Label {
            Text(komgaReadList.lastModifiedDate.formatted(date: .abbreviated, time: .omitted))
          } icon: {
            Image(systemName: "clock")
          }
          .font(.caption)
          .foregroundColor(.secondary)

          if !komgaReadList.summary.isEmpty {
            Text(komgaReadList.summary)
              .font(.caption)
              .foregroundColor(.secondary)
              .lineLimit(2)
          }

        }

        Spacer()

        Image(systemName: "chevron.right")
          .foregroundColor(.secondary)
      }
    }
    .adaptiveButtonStyle(.plain)
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
