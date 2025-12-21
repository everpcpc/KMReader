//
//  CollectionDetailView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftData
import SwiftUI

struct CollectionDetailView: View {
  let collectionId: String

  @AppStorage("browseColumns") private var browseColumns: BrowseColumns = BrowseColumns()
  @AppStorage("isAdmin") private var isAdmin: Bool = false

  @Environment(\.dismiss) private var dismiss

  // SwiftData query for reactive updates
  @Query private var komgaCollections: [KomgaCollection]

  @State private var seriesViewModel = SeriesViewModel()
  @State private var showDeleteConfirmation = false
  @State private var showEditSheet = false
  @State private var showFilterSheet = false
  @State private var containerWidth: CGFloat = 0
  @State private var layoutHelper = BrowseLayoutHelper()

  init(collectionId: String) {
    self.collectionId = collectionId
    let instanceId = AppConfig.currentInstanceId
    let compositeId = "\(instanceId)_\(collectionId)"
    _komgaCollections = Query(filter: #Predicate<KomgaCollection> { $0.id == compositeId })
  }

  /// The KomgaCollection from SwiftData (reactive).
  private var komgaCollection: KomgaCollection? {
    komgaCollections.first
  }

  /// Convert to API SeriesCollection type for compatibility with existing components.
  private var collection: SeriesCollection? {
    komgaCollection?.toCollection()
  }

  // SwiftUI's default horizontal padding is 16 on each side (32 total)
  private let horizontalPadding: CGFloat = 16

  var body: some View {
    ScrollView {
      VStack(alignment: .leading) {
        if let collection = collection {
          // Header with thumbnail and info
          Text(collection.name)
            .font(.title2)

          HStack(alignment: .top) {
            ThumbnailImage(
              id: collectionId, type: .collection, showPlaceholder: false,
              width: PlatformHelper.detailThumbnailWidth
            )
            .thumbnailFocus()

            VStack(alignment: .leading) {

              // Info chips
              VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                  InfoChip(
                    labelKey: "\(collection.seriesIds.count) series",
                    systemImage: "square.grid.2x2",
                    backgroundColor: Color.blue.opacity(0.2),
                    foregroundColor: .blue
                  )
                  if collection.ordered {
                    InfoChip(
                      labelKey: "Ordered",
                      systemImage: "arrow.up.arrow.down",
                      backgroundColor: Color.cyan.opacity(0.2),
                      foregroundColor: .cyan
                    )
                  }
                }
                InfoChip(
                  labelKey: "Created: \(formatDate(collection.createdDate))",
                  systemImage: "calendar.badge.plus",
                  backgroundColor: Color.blue.opacity(0.2),
                  foregroundColor: .blue
                )
                InfoChip(
                  labelKey: "Modified: \(formatDate(collection.lastModifiedDate))",
                  systemImage: "clock",
                  backgroundColor: Color.purple.opacity(0.2),
                  foregroundColor: .purple
                )

              }
            }
          }

          #if os(tvOS)
            collectionToolbarContent
              .padding(.vertical, 8)
          #endif

          // Series list
          if containerWidth > 0 {
            CollectionSeriesListView(
              collectionId: collectionId,
              seriesViewModel: seriesViewModel,
              layoutHelper: layoutHelper,
              showFilterSheet: $showFilterSheet
            )
          }
        } else {
          ProgressView()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
      }
      .padding(.horizontal, horizontalPadding)
    }
    .inlineNavigationBarTitle(String(localized: "title.collection"))
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
    #if !os(tvOS)
      .toolbar {
        ToolbarItem(placement: .automatic) {
          collectionToolbarContent
        }
      }
    #endif
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
    .onGeometryChange(for: CGSize.self) { geometry in
      geometry.size
    } action: { newSize in
      let newContentWidth = max(0, newSize.width - horizontalPadding * 2)
      if abs(containerWidth - newContentWidth) > 1 {
        containerWidth = newContentWidth
        layoutHelper = BrowseLayoutHelper(
          width: newContentWidth,
          browseColumns: browseColumns
        )
      }
    }
    .onChange(of: browseColumns) { _, _ in
      if containerWidth > 0 {
        layoutHelper = BrowseLayoutHelper(
          width: containerWidth - horizontalPadding * 2,
          browseColumns: browseColumns
        )
      }
    }
  }
}

// Helper functions for CollectionDetailView
extension CollectionDetailView {
  private func loadCollectionDetails() async {
    do {
      // Sync from network to SwiftData (collection property will update reactively)
      _ = try await SyncService.shared.syncCollection(id: collectionId)
    } catch {
      if komgaCollection == nil {
        ErrorManager.shared.alert(error: error)
      }
    }
  }

  @MainActor
  private func deleteCollection() async {
    do {
      try await CollectionService.shared.deleteCollection(collectionId: collectionId)
      await MainActor.run {
        ErrorManager.shared.notify(message: String(localized: "notification.collection.deleted"))
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

  @ViewBuilder
  private var collectionToolbarContent: some View {
    HStack(spacing: PlatformHelper.buttonSpacing) {
      Button {
        showFilterSheet = true
      } label: {
        Image(systemName: "line.3.horizontal.decrease.circle")
      }
      .toolbarButtonStyle()

      actionsMenu
    }
  }

  @ViewBuilder
  private var actionsMenu: some View {
    Menu {
      Button {
        showEditSheet = true
      } label: {
        Label("Edit", systemImage: "pencil")
      }
      .disabled(!isAdmin)

      Divider()

      Button(role: .destructive) {
        showDeleteConfirmation = true
      } label: {
        Label("Delete Collection", systemImage: "trash")
      }
      .disabled(!isAdmin)
    } label: {
      Image(systemName: "ellipsis.circle")
    }
    .toolbarButtonStyle()
  }
}
