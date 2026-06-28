//
// ReadListCompactCardView.swift
//
//

import SwiftUI

@MainActor
struct ReadListCompactCardView: View {
  let item: ReadListDisplayItem
  var coverWidth: CGFloat = 80
  var onChanged: () -> Void = {}
  let onDeleteRequested: () -> Void

  @State private var showEditSheet = false

  var body: some View {
    NavigationLink(value: NavDestination.readListDetail(readListId: item.readListId)) {
      HStack(alignment: .top, spacing: 10) {
        ThumbnailImage(id: item.readListId, type: .readlist, width: coverWidth)
          .frame(width: coverWidth)
          .allowsHitTesting(false)

        VStack(alignment: .leading, spacing: 4) {
          Text(item.name)
            .font(.headline)
            .fontWeight(.medium)
            .lineLimit(2)
            .multilineTextAlignment(.leading)

          Text("\(item.bookCount) books")
            .font(.footnote)
            .foregroundColor(.secondary)

          Text(item.lastModifiedDate.formattedMediumDate)
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
        onMutationCompleted: onChanged
      )
    }
    .sheet(isPresented: $showEditSheet, onDismiss: onChanged) {
      ReadListEditSheet(readList: item.readList)
    }
  }

  private func togglePinned() {
    let nextPinned = !item.isPinned
    Task {
      do {
        let database = try await DatabaseOperator.database()
        await database.setReadListPinned(
          readListId: item.readListId,
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
