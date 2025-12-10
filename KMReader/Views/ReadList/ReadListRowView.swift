//
//  ReadListRowView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct ReadListRowView: View {
  let readList: ReadList
  var onActionCompleted: (() -> Void)? = nil

  @State private var showEditSheet = false
  @State private var showDeleteConfirmation = false

  private var thumbnailURL: URL? {
    ReadListService.shared.getReadListThumbnailURL(id: readList.id)
  }

  var body: some View {
    NavigationLink(value: NavDestination.readListDetail(readListId: readList.id)) {
      HStack(spacing: 12) {
        ThumbnailImage(url: thumbnailURL, width: 70, cornerRadius: 10)

        VStack(alignment: .leading, spacing: 6) {
          Text(readList.name)
            .font(.callout)

          Label {
            Text("\(readList.bookIds.count) book")
          } icon: {
            Image(systemName: "book")
          }
          .font(.footnote)
          .foregroundColor(.secondary)

          Label {
            Text(readList.lastModifiedDate.formatted(date: .abbreviated, time: .omitted))
          } icon: {
            Image(systemName: "clock")
          }
          .font(.caption)
          .foregroundColor(.secondary)

          if !readList.summary.isEmpty {
            Text(readList.summary)
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
