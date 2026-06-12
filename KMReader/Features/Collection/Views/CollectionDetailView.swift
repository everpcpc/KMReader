//
// CollectionDetailView.swift
//
//

import SwiftUI

struct CollectionDetailView: View {
  let collectionId: String
  let readerPresentation: ReaderPresentationManager

  @AppStorage("currentAccount") private var current: Current = .init()
  @AppStorage("collectionDetailLayout") private var collectionDetailLayout: BrowseLayoutMode = .list

  @Environment(\.dismiss) private var dismiss

  @State private var item: CollectionDisplayItem?
  @State private var showDeleteConfirmation = false
  @State private var showEditSheet = false
  @State private var showFilterSheet = false
  @State private var showSavedFilters = false

  init(
    collectionId: String,
    readerPresentation: ReaderPresentationManager
  ) {
    self.collectionId = collectionId
    self.readerPresentation = readerPresentation
  }

  private var collection: SeriesCollection? {
    item?.collection
  }

  private var navigationTitle: String {
    collection?.name ?? String(localized: "title.collection")
  }

  private var isPinned: Bool {
    item?.isPinned ?? false
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
          if item != nil {
            CollectionSeriesListView(
              collectionId: collectionId,
              readerPresentation: readerPresentation,
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
    #if os(iOS) || os(macOS)
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
    await loadLocalCollection()
    do {
      _ = try await SyncService.syncCollection(id: collectionId)
    } catch {
      if case APIError.notFound = error {
        dismiss()
      } else if item == nil {
        ErrorManager.shared.alert(error: error)
      }
    }
    await loadLocalCollection()
  }

  private func loadLocalCollection() async {
    guard let database = try? await DatabaseOperator.database() else {
      item = nil
      return
    }
    item = try? await database.fetchCollectionDisplayItem(
      collectionId: collectionId,
      instanceId: current.instanceId
    )
  }

  @MainActor
  private func deleteCollection() async {
    do {
      try await CollectionService.deleteCollection(collectionId: collectionId)
      ErrorManager.shared.notify(message: String(localized: "notification.collection.deleted"))
      dismiss()
    } catch {
      ErrorManager.shared.alert(error: error)
    }
  }

  private func togglePinned() {
    guard let item else { return }
    let nextPinned = !item.isPinned
    Task {
      try? await DatabaseOperator.database().setCollectionPinned(
        collectionId: item.collectionId,
        instanceId: item.instanceId,
        isPinned: nextPinned
      )
      try? await DatabaseOperator.database().commit()
      await loadLocalCollection()
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

      Button {
        togglePinned()
      } label: {
        Label(
          isPinned ? String(localized: "action.unpinFromTop") : String(localized: "action.pinToTop"),
          systemImage: isPinned ? "pin.slash" : "pin"
        )
      }

      if current.isAdmin {
        Divider()

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
  }
}
