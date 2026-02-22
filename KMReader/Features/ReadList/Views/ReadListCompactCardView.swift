//
// ReadListCompactCardView.swift
//
//

import SwiftUI

struct ReadListCompactCardView: View {
  @Bindable var komgaReadList: KomgaReadList
  var coverWidth: CGFloat = 80
  @State private var showEditSheet = false
  @State private var showDeleteConfirmation = false

  var body: some View {
    NavigationLink(value: NavDestination.readListDetail(readListId: komgaReadList.readListId)) {
      HStack(alignment: .top, spacing: 10) {
        ThumbnailImage(id: komgaReadList.readListId, type: .readlist, width: coverWidth)
          .frame(width: coverWidth)
          .allowsHitTesting(false)

        VStack(alignment: .leading, spacing: 4) {
          Text(komgaReadList.name)
            .font(.headline)
            .fontWeight(.medium)
            .lineLimit(2)
            .multilineTextAlignment(.leading)

          Text("\(komgaReadList.bookIds.count) books")
            .font(.footnote)
            .foregroundColor(.secondary)

          Text(komgaReadList.lastModifiedDate.formattedMediumDate)
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }
      .padding(8)
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
      ReadListContextMenu(
        readListId: komgaReadList.readListId,
        menuTitle: komgaReadList.name,
        downloadStatus: komgaReadList.downloadStatus,
        isPinned: komgaReadList.isPinned,
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
        ErrorManager.shared.notify(message: String(localized: "notification.readList.deleted"))
      } catch {
        ErrorManager.shared.alert(error: error)
      }
    }
  }

  private func togglePinned() {
    let nextPinned = !komgaReadList.isPinned
    Task {
      await DatabaseOperator.shared.setReadListPinned(
        readListId: komgaReadList.readListId,
        instanceId: komgaReadList.instanceId,
        isPinned: nextPinned
      )
      await DatabaseOperator.shared.commit()
    }
  }
}
