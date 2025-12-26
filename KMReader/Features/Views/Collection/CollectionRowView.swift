//
//  CollectionRowView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct CollectionRowView: View {
  @Bindable var komgaCollection: KomgaCollection
  var onActionCompleted: (() -> Void)? = nil

  @State private var showEditSheet = false
  @State private var showDeleteConfirmation = false

  var body: some View {
    CardView {
      HStack(spacing: 12) {
        ThumbnailImage(id: komgaCollection.collectionId, type: .collection, width: 60)

        VStack(alignment: .leading, spacing: 6) {
          Text(komgaCollection.name)
            .font(.callout)
          Text("\(komgaCollection.seriesIds.count) series")
            .font(.footnote)
            .foregroundColor(.secondary)

          HStack(spacing: 12) {
            Label {
              Text(komgaCollection.createdDate.formatted(date: .abbreviated, time: .omitted))
            } icon: {
              Image(systemName: "calendar")
            }
            .font(.caption)
            .foregroundColor(.secondary)

            Label {
              Text(komgaCollection.lastModifiedDate.formatted(date: .abbreviated, time: .omitted))
            } icon: {
              Image(systemName: "clock")
            }
            .font(.caption)
            .foregroundColor(.secondary)
          }
        }

        Spacer()

        Image(systemName: "chevron.right")
          .foregroundColor(.secondary)
          .padding(.trailing)
      }
    }
    .adaptiveButtonStyle(.plain)
    .contentShape(Rectangle())
    .contextMenu {
      CollectionContextMenu(
        collection: komgaCollection.toCollection(),
        onActionCompleted: onActionCompleted,
        onDeleteRequested: {
          showDeleteConfirmation = true
        },
        onEditRequested: {
          showEditSheet = true
        }
      )
    }
    .alert("Delete Collection", isPresented: $showDeleteConfirmation) {
      Button("Cancel", role: .cancel) {}
      Button("Delete", role: .destructive) {
        deleteCollection()
      }
    } message: {
      Text("Are you sure you want to delete this collection? This action cannot be undone.")
    }
    .sheet(isPresented: $showEditSheet) {
      CollectionEditSheet(collection: komgaCollection.toCollection())
        .onDisappear {
          onActionCompleted?()
        }
    }
  }

  private func deleteCollection() {
    Task {
      do {
        try await CollectionService.shared.deleteCollection(
          collectionId: komgaCollection.collectionId)
        await MainActor.run {
          ErrorManager.shared.notify(message: String(localized: "notification.collection.deleted"))
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
