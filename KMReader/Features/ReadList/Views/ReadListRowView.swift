//
// ReadListRowView.swift
//
//

import SwiftUI

struct ReadListRowView: View {
  let item: ReadListDisplayItem
  var onMutationCompleted: (() -> Void)? = nil

  @State private var showEditSheet = false
  @State private var showDeleteConfirmation = false

  var body: some View {
    HStack(spacing: 12) {
      NavigationLink(value: NavDestination.readListDetail(readListId: item.readListId)) {
        ThumbnailImage(id: item.readListId, type: .readlist, width: 60)
      }
      .adaptiveButtonStyle(.plain)

      VStack(alignment: .leading, spacing: 6) {
        NavigationLink(value: NavDestination.readListDetail(readListId: item.readListId)) {
          HStack(spacing: 6) {
            Text(item.name)
              .font(.callout)
              .lineLimit(2)
            if item.isPinned {
              Image(systemName: "pin.fill")
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
          }
        }.adaptiveButtonStyle(.plain)

        HStack {
          VStack(alignment: .leading, spacing: 4) {
            Label("\(item.bookCount) books", systemImage: ContentIcon.book)
              .font(.footnote)
              .foregroundColor(.secondary)

            Label(
              item.lastModifiedDate.formatted(date: .abbreviated, time: .omitted),
              systemImage: "clock"
            )
            .font(.caption)
            .foregroundColor(.secondary)

            if !item.summary.isEmpty {
              Text(item.summary)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
            }
          }

          Spacer()

          EllipsisMenuButton {
            ReadListContextMenu(
              readListId: item.readListId,
              menuTitle: item.name,
              downloadStatus: item.downloadStatus,
              offlinePolicy: item.offlinePolicy,
              offlinePolicyLimit: item.offlinePolicyLimit,
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
            .id(item.readListId)
          }
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
      ReadListEditSheet(readList: item.readList)
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
      onMutationCompleted?()
    }
  }
}
