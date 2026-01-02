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

  @AppStorage("isAdmin") private var isAdmin: Bool = false
  @AppStorage("collectionDetailLayout") private var collectionDetailLayout: BrowseLayoutMode = .list

  @Environment(\.dismiss) private var dismiss

  // SwiftData query for reactive updates
  @Query private var komgaCollections: [KomgaCollection]

  @State private var showDeleteConfirmation = false
  @State private var showEditSheet = false
  @State private var showFilterSheet = false

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
            collection: collection
          ).padding(.horizontal)

          // Series list
          if komgaCollection != nil {
            CollectionSeriesListView(
              collectionId: collectionId,
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
  }
}

// Helper functions for CollectionDetailView
extension CollectionDetailView {
  private func loadCollectionDetails() async {
    do {
      // Sync from network to SwiftData (collection property will update reactively)
      try await SyncService.shared.syncCollection(id: collectionId)
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

  @ViewBuilder
  private var collectionToolbarContent: some View {
    HStack {
      LayoutModePicker(selection: $collectionDetailLayout)

      Button {
        showFilterSheet = true
      } label: {
        Image(systemName: "line.3.horizontal.decrease.circle")
      }

      actionsMenu
    }.toolbarButtonStyle()
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
  }
}
