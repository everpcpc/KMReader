//
//  CollectionDetailView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct CollectionDetailView: View {
  let collectionId: String

  @AppStorage("collectionDetailLayout") private var layoutMode: BrowseLayoutMode = .grid
  @AppStorage("browseColumns") private var browseColumns: BrowseColumns = BrowseColumns()

  @Environment(\.dismiss) private var dismiss

  @State private var seriesViewModel = SeriesViewModel()
  @State private var collection: KomgaCollection?
  @State private var showDeleteConfirmation = false
  @State private var showEditSheet = false

  private var thumbnailURL: URL? {
    collection.flatMap { CollectionService.shared.getCollectionThumbnailURL(id: $0.id) }
  }

  var body: some View {
    GeometryReader { geometry in
      ScrollView {
        VStack(alignment: .leading) {
          if let collection = collection {
            // Header with thumbnail and info
            HStack(alignment: .top) {
              ThumbnailImage(url: thumbnailURL, showPlaceholder: false, width: 120)

              VStack(alignment: .leading) {
                Text(collection.name)
                  .font(.title3)

                // Info chips
                VStack(alignment: .leading, spacing: 6) {
                  HStack(spacing: 6) {
                    InfoChip(
                      label: "\(collection.seriesIds.count) series",
                      systemImage: "square.grid.2x2",
                      backgroundColor: Color.blue.opacity(0.2),
                      foregroundColor: .blue
                    )
                    if collection.ordered {
                      InfoChip(
                        label: "Ordered",
                        systemImage: "arrow.up.arrow.down",
                        backgroundColor: Color.cyan.opacity(0.2),
                        foregroundColor: .cyan
                      )
                    }
                  }
                  InfoChip(
                    label: "Created: \(formatDate(collection.createdDate))",
                    systemImage: "calendar.badge.plus",
                    backgroundColor: Color.blue.opacity(0.2),
                    foregroundColor: .blue
                  )
                  InfoChip(
                    label: "Modified: \(formatDate(collection.lastModifiedDate))",
                    systemImage: "clock",
                    backgroundColor: Color.purple.opacity(0.2),
                    foregroundColor: .purple
                  )

                }
              }
            }

            // Series list
            CollectionSeriesListView(
              collectionId: collectionId,
              seriesViewModel: seriesViewModel,
              layoutMode: layoutMode,
              layoutHelper: BrowseLayoutHelper(
                width: geometry.size.width - 32,
                height: geometry.size.height,
                spacing: 12,
                browseColumns: browseColumns
              )
            )
          } else {
            ProgressView()
              .frame(maxWidth: .infinity, maxHeight: .infinity)
          }
        }
        .padding(.horizontal)
      }
      .navigationTitle("Collection")
      #if canImport(UIKit)
        .navigationBarTitleDisplayMode(.inline)
      #endif
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
        ToolbarItem(placement: .automatic) {
          HStack(spacing: 8) {
            Menu {
              Picker("Layout", selection: $layoutMode) {
                ForEach(BrowseLayoutMode.allCases) { mode in
                  Label(mode.displayName, systemImage: mode.iconName).tag(mode)
                }
              }
              .pickerStyle(.inline)
            } label: {
              Image(systemName: layoutMode.iconName)
            }

            Menu {
              Button {
                showEditSheet = true
              } label: {
                Label("Edit", systemImage: "pencil")
              }
              .disabled(!AppConfig.isAdmin)

              Divider()

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
      }
      .sheet(isPresented: $showEditSheet) {
        if let collection = collection {
          CollectionEditSheet(collection: collection)
            .onDisappear {
              Task {
                await loadCollectionDetails()
              }
            }
        }
      }
      .task {
        await loadCollectionDetails()
      }
    }
  }
}

// Helper functions for CollectionDetailView
extension CollectionDetailView {
  private func loadCollectionDetails() async {
    do {
      collection = try await CollectionService.shared.getCollection(id: collectionId)
    } catch {
      ErrorManager.shared.alert(error: error)
    }
  }

  @MainActor
  private func deleteCollection() async {
    do {
      try await CollectionService.shared.deleteCollection(collectionId: collectionId)
      await MainActor.run {
        ErrorManager.shared.notify(message: "Collection deleted")
        dismiss()
      }
    } catch {
      ErrorManager.shared.alert(error: error)
    }
  }

  private func formatDate(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .none
    return formatter.string(from: date)
  }
}
