//
//  CollectionPickerSheet.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftData
import SwiftUI

struct CollectionPickerSheet: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.modelContext) private var modelContext
  @AppStorage("dashboard") private var dashboard: DashboardConfiguration = DashboardConfiguration()
  @AppStorage("isAdmin") private var isAdmin: Bool = false

  @State private var collectionViewModel = CollectionViewModel()
  @State private var selectedCollectionId: String?
  @State private var isLoading = false
  @State private var searchText: String = ""
  @State private var showCreateSheet = false
  @State private var isCreating = false

  @Query private var komgaCollections: [KomgaCollection]

  let seriesIds: [String]
  let onSelect: (String) -> Void
  let onComplete: (() -> Void)?

  init(
    seriesIds: [String] = [],
    onSelect: @escaping (String) -> Void,
    onComplete: (() -> Void)? = nil
  ) {
    self.seriesIds = seriesIds
    self.onSelect = onSelect
    self.onComplete = onComplete

    let instanceId = AppConfig.currentInstanceId
    _komgaCollections = Query(
      filter: #Predicate<KomgaCollection> { $0.instanceId == instanceId },
      sort: [SortDescriptor(\KomgaCollection.name, order: .forward)]
    )
  }

  private var collections: [SeriesCollection] {
    let ids = Set(collectionViewModel.collectionIds)
    return komgaCollections
      .filter { ids.contains($0.collectionId) }
      .map { $0.toCollection() }
  }

  var body: some View {
    SheetView(title: String(localized: "Select Collection"), size: .large, applyFormStyle: true) {
      Form {
        if isLoading && collections.isEmpty {
          ProgressView()
            .frame(maxWidth: .infinity)
        } else if collections.isEmpty && searchText.isEmpty {
          Text("No collections found")
            .foregroundColor(.secondary)
        } else {
          Picker("Collection", selection: $selectedCollectionId) {
            ForEach(collections) { collection in
              Label(collection.name, systemImage: "square.grid.2x2").tag(collection.id as String?)
            }
          }
          .pickerStyle(.inline)
        }
      }
    } controls: {
      Button {
        showCreateSheet = true
      } label: {
        Label("Create New", systemImage: "plus.circle.fill")
      }
      .disabled(!isAdmin)

      HStack(spacing: 12) {
        Button(action: confirmSelection) {
          Label("Done", systemImage: "checkmark")
        }
        .disabled(selectedCollectionId == nil)
      }
    }
    .searchable(text: $searchText)
    .task {
      await loadCollections()
    }
    .onChange(of: searchText) { _, newValue in
      Task {
        await loadCollections(searchText: newValue)
      }
    }
    .sheet(isPresented: $showCreateSheet) {
      CreateCollectionSheet(
        isCreating: $isCreating,
        seriesIds: seriesIds,
        onCreate: { _ in
          onComplete?()
          dismiss()
        }
      )
    }
  }

  private func loadCollections(searchText: String = "") async {
    isLoading = true

    await collectionViewModel.loadCollections(
      context: modelContext,
      libraryIds: dashboard.libraryIds,
      sort: "name,asc",
      searchText: searchText,
      refresh: true
    )

    isLoading = false
  }

  private func confirmSelection() {
    if let selectedCollectionId = selectedCollectionId {
      onSelect(selectedCollectionId)
      dismiss()
    }
  }
}

struct CreateCollectionSheet: View {
  @Environment(\.dismiss) private var dismiss
  @Binding var isCreating: Bool
  let seriesIds: [String]
  let onCreate: (String) -> Void

  @State private var name: String = ""

  var body: some View {
    SheetView(title: String(localized: "Create Collection"), size: .medium, applyFormStyle: true) {
      Form {
        Section {
          TextField("Collection Name", text: $name)
        }
      }
    } controls: {
      Button(action: createCollection) {
        if isCreating {
          ProgressView()
        } else {
          Label("Create", systemImage: "checkmark")
        }
      }
      .disabled(name.isEmpty || isCreating)
    }
  }

  private func createCollection() {
    guard !name.isEmpty else { return }

    isCreating = true

    Task {
      do {
        let collection = try await CollectionService.shared.createCollection(
          name: name,
          seriesIds: seriesIds
        )
        // Sync the collection to update its seriesIds in local SwiftData
        _ = try? await SyncService.shared.syncCollection(id: collection.id)
        await MainActor.run {
          ErrorManager.shared.notify(message: String(localized: "notification.collection.created"))
          isCreating = false
          onCreate(collection.id)
          dismiss()
        }
      } catch {
        await MainActor.run {
          isCreating = false
          ErrorManager.shared.alert(error: error)
        }
      }
    }
  }
}
