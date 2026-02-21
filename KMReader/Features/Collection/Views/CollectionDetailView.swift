//
// CollectionDetailView.swift
//
//

import SQLiteData
import SwiftUI

struct CollectionDetailView: View {
  let collectionId: String

  @AppStorage("currentAccount") private var current: Current = .init()
  @AppStorage("collectionDetailLayout") private var collectionDetailLayout: BrowseLayoutMode = .list

  @Environment(\.dismiss) private var dismiss

  @FetchAll private var komgaCollections: [KomgaCollectionRecord]

  @State private var showDeleteConfirmation = false
  @State private var showEditSheet = false
  @State private var showFilterSheet = false
  @State private var showSavedFilters = false

  init(collectionId: String) {
    self.collectionId = collectionId
    let instanceId = AppConfig.current.instanceId
    _komgaCollections = FetchAll(
      KomgaCollectionRecord.where { $0.instanceId.eq(instanceId) && $0.collectionId.eq(collectionId) }.limit(1)
    )
  }

  private var komgaCollection: KomgaCollectionRecord? {
    komgaCollections.first
  }

  private var collection: SeriesCollection? {
    komgaCollection?.toCollection()
  }

  private var navigationTitle: String {
    collection?.name ?? String(localized: "title.collection")
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
              showFilterSheet: $showFilterSheet,
              showSavedFilters: $showSavedFilters
            )
          }
        } else {
          ProgressView()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
      }
    }
    .inlineNavigationBarTitle(navigationTitle)
    .komgaHandoff(
      title: navigationTitle,
      url: KomgaWebLinkBuilder.collection(serverURL: current.serverURL, collectionId: collectionId),
      scope: .browse
    )
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
    .sheet(isPresented: $showSavedFilters) {
      SavedFiltersView(filterType: .collectionSeries)
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
      _ = try await SyncService.shared.syncCollection(id: collectionId)
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
      ErrorManager.shared.notify(message: String(localized: "notification.collection.deleted"))
      dismiss()
    } catch {
      ErrorManager.shared.alert(error: error)
    }
  }

  @ViewBuilder
  private var collectionToolbarContent: some View {
    HStack {
      Button {
        showSavedFilters = true
      } label: {
        Image(systemName: "bookmark")
      }

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
      LayoutModePicker(selection: $collectionDetailLayout)

      Divider()

      if current.isAdmin {
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
      Image(systemName: "ellipsis")
    }
    .appMenuStyle()
  }
}
