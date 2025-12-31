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

  @State private var showDeleteConfirmation = false
  @State private var showEditSheet = false
  @State private var showFilterSheet = false
  @State private var containerWidth: CGFloat = 0
  @State private var layoutHelper = BrowseLayoutHelper()
  @State private var thumbnailRefreshTrigger = 0

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

  var body: some View {
    ScrollView {
      VStack(alignment: .leading) {
        if let collection = collection {

          #if os(tvOS)
            collectionToolbarContent
              .padding(.vertical, 8)
          #endif

          CollectionDetailContentView(
            collection: collection,
            thumbnailRefreshTrigger: $thumbnailRefreshTrigger
          ).padding(.horizontal)

          // Series list
          if containerWidth > 0 {
            CollectionSeriesListView(
              collectionId: collectionId,
              layoutHelper: layoutHelper,
              showFilterSheet: $showFilterSheet
            )
          }
        } else {
          ProgressView()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
      }
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
    .onContainerWidthChange { newWidth in
      containerWidth = newWidth
      layoutHelper = BrowseLayoutHelper(
        width: newWidth,
        browseColumns: browseColumns
      )
    }
    .onChange(of: browseColumns) { _, _ in
      if containerWidth > 0 {
        layoutHelper = BrowseLayoutHelper(
          width: containerWidth,
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
      let previousLastModified = komgaCollection?.lastModifiedDate
      let fetchedCollection = try await SyncService.shared.syncCollection(id: collectionId)
      if previousLastModified != fetchedCollection.lastModifiedDate {
        reloadThumbnail()
      }
    } catch {
      if case APIError.notFound = error {
        dismiss()
      } else if komgaCollection == nil {
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

  private func reloadThumbnail() {
    guard !AppConfig.isOffline else { return }
    thumbnailRefreshTrigger += 1
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
      if isAdmin {
        Button {
          showEditSheet = true
        } label: {
          Label("Edit", systemImage: "pencil")
        }

        Divider()

        Button(role: .destructive) {
          showDeleteConfirmation = true
        } label: {
          Label("Delete Collection", systemImage: "trash")
        }
      }
    } label: {
      Image(systemName: "ellipsis.circle")
    }
    .toolbarButtonStyle()
  }
}
