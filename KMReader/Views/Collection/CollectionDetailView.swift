//
//  CollectionDetailView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct CollectionDetailView: View {
  let collectionId: String

  @Environment(\.dismiss) private var dismiss

  @State private var seriesViewModel = SeriesViewModel()
  @State private var collection: Collection?
  @State private var actionErrorMessage: String?
  @State private var showDeleteConfirmation = false

  private var thumbnailURL: URL? {
    collection.flatMap { CollectionService.shared.getCollectionThumbnailURL(id: $0.id) }
  }

  private var isActionErrorPresented: Binding<Bool> {
    Binding(
      get: { actionErrorMessage != nil },
      set: { if !$0 { actionErrorMessage = nil } }
    )
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        if let collection = collection {
          // Header with thumbnail and info
          HStack(alignment: .top, spacing: 16) {
            ThumbnailImage(url: thumbnailURL, showPlaceholder: false, width: 120)

            VStack(alignment: .leading) {
              Text(collection.name)
                .font(.title2)

              // Series count
              Text("\(collection.seriesIds.count) series")
                .font(.caption)
                .foregroundColor(.secondary)

              // Info chips
              VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                  InfoChip(
                    label: collection.createdDate.formatted(date: .abbreviated, time: .omitted),
                    systemImage: "calendar.badge.plus",
                    backgroundColor: Color.blue.opacity(0.2),
                    foregroundColor: .blue
                  )
                  InfoChip(
                    label: collection.lastModifiedDate.formatted(
                      date: .abbreviated, time: .omitted),
                    systemImage: "clock",
                    backgroundColor: Color.purple.opacity(0.2),
                    foregroundColor: .purple
                  )
                }
                if collection.ordered {
                  InfoChip(
                    label: "Ordered",
                    systemImage: "arrow.up.arrow.down",
                    backgroundColor: Color.cyan.opacity(0.2),
                    foregroundColor: .cyan
                  )
                }
              }
            }

            Spacer()
          }

          // Series list
          SeriesListView(
            collectionId: collectionId,
            seriesViewModel: seriesViewModel
          )
        } else {
          ProgressView()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
      }
      .padding(.horizontal)
    }
    .navigationTitle("Collection")
    .navigationBarTitleDisplayMode(.inline)
    .alert("Action Failed", isPresented: isActionErrorPresented) {
      Button("OK", role: .cancel) {}
    } message: {
      if let actionErrorMessage {
        Text(actionErrorMessage)
      }
    }
    .alert("Delete Collection?", isPresented: $showDeleteConfirmation) {
      Button("Delete", role: .destructive) {
        Task {
          await deleteCollection()
        }
      }
      Button("Cancel", role: .cancel) {}
    } message: {
      Text("This will permanently delete \(collection?.name ?? "this collection") from Komga.")
    }
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Menu {
          Button(role: .destructive) {
            showDeleteConfirmation = true
          } label: {
            Label("Delete Collection", systemImage: "trash")
          }
          .disabled(!AppConfig.isAdmin)
        } label: {
          Image(systemName: "ellipsis.circle")
        }
      }
    }
    .task {
      await loadCollectionDetails()
    }
  }
}

// Helper functions for CollectionDetailView
extension CollectionDetailView {
  private func loadCollectionDetails() async {
    do {
      collection = try await CollectionService.shared.getCollection(id: collectionId)
    } catch {
      actionErrorMessage = error.localizedDescription
    }
  }

  @MainActor
  private func deleteCollection() async {
    do {
      try await CollectionService.shared.deleteCollection(collectionId: collectionId)
      dismiss()
    } catch {
      actionErrorMessage = error.localizedDescription
    }
  }
}
