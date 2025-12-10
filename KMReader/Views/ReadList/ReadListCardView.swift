//
//  ReadListCardView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct ReadListCardView: View {
  let readList: ReadList
  let width: CGFloat
  var onActionCompleted: (() -> Void)? = nil

  @State private var showEditSheet = false
  @State private var showDeleteConfirmation = false

  private var bookCountText: String {
    let count = readList.bookIds.count
    return count == 1 ? "1 book" : "\(count) books"
  }

  private var thumbnailURL: URL? {
    ReadListService.shared.getReadListThumbnailURL(id: readList.id)
  }

  var body: some View {
    NavigationLink(value: NavDestination.readListDetail(readListId: readList.id)) {
      VStack(alignment: .leading, spacing: 8) {
        ThumbnailImage(url: thumbnailURL, width: width, cornerRadius: 12)

        VStack(alignment: .leading, spacing: 4) {
          Text(readList.name)
            .font(.headline)
            .lineLimit(1)

          Text(bookCountText)
            .font(.caption)
            .foregroundColor(.secondary)

          if !readList.summary.isEmpty {
            Text(readList.summary)
              .font(.caption)
              .foregroundColor(.secondary)
              .lineLimit(2)
          }
        }
        .frame(width: width, alignment: .leading)
      }
      .frame(maxHeight: .infinity, alignment: .top)
    }
    .adaptiveButtonStyle(.plain)
    .contextMenu {
      ReadListContextMenu(
        readList: readList,
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
      ReadListEditSheet(readList: readList)
        .onDisappear {
          onActionCompleted?()
        }
    }
  }

  private func deleteReadList() {
    Task {
      do {
        try await ReadListService.shared.deleteReadList(readListId: readList.id)
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
