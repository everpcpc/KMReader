//
// ReadListRowView.swift
//
//

import SwiftUI

struct ReadListRowView: View {
  let readList: ReadList
  let localState: KomgaReadListLocalStateRecord?

  @State private var showEditSheet = false
  @State private var showDeleteConfirmation = false

  private var downloadStatus: SeriesDownloadStatus {
    (localState ?? .empty(instanceId: AppConfig.current.instanceId, readListId: readList.id))
      .downloadStatus(totalBooks: readList.bookIds.count)
  }

  var body: some View {
    HStack(spacing: 12) {
      NavigationLink(value: NavDestination.readListDetail(readListId: readList.id)) {
        ThumbnailImage(id: readList.id, type: .readlist, width: 60)
      }
      .adaptiveButtonStyle(.plain)

      VStack(alignment: .leading, spacing: 6) {
        NavigationLink(value: NavDestination.readListDetail(readListId: readList.id)) {
          Text(readList.name)
            .font(.callout)
            .lineLimit(2)
        }.adaptiveButtonStyle(.plain)

        HStack {
          VStack(alignment: .leading, spacing: 4) {
            Label("\(readList.bookIds.count) books", systemImage: ContentIcon.book)
              .font(.footnote)
              .foregroundColor(.secondary)

            Label(
              readList.lastModifiedDate.formatted(date: .abbreviated, time: .omitted),
              systemImage: "clock"
            )
            .font(.caption)
            .foregroundColor(.secondary)

            if !readList.summary.isEmpty {
              Text(readList.summary)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
            }
          }

          Spacer()

          EllipsisMenuButton {
            ReadListContextMenu(
              readListId: readList.id,
              menuTitle: readList.name,
              downloadStatus: downloadStatus,
              onDeleteRequested: {
                showDeleteConfirmation = true
              },
              onEditRequested: {
                showEditSheet = true
              }
            )
            .id(readList.id)
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
      ReadListEditSheet(readList: readList)
    }
  }

  private func deleteReadList() {
    Task {
      do {
        try await ReadListService.shared.deleteReadList(readListId: readList.id)
        ErrorManager.shared.notify(message: String(localized: "notification.readList.deleted"))
      } catch {
        ErrorManager.shared.alert(error: error)
      }
    }
  }
}
