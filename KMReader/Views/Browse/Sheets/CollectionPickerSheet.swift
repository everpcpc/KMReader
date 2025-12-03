//
//  CollectionPickerSheet.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct CollectionPickerSheet: View {
  @Environment(\.dismiss) private var dismiss
  @AppStorage("dashboard") private var dashboard: DashboardConfiguration = DashboardConfiguration()
  @AppStorage("isAdmin") private var isAdmin: Bool = false

  @State private var collectionViewModel = CollectionViewModel()
  @State private var selectedCollectionId: String?
  @State private var isLoading = false
  @State private var searchText: String = ""
  @State private var showCreateSheet = false
  @State private var isCreating = false

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
  }

  var body: some View {
    SheetView(title: "Select Collection", size: .large) {
      Form {
        if isLoading && collectionViewModel.collections.isEmpty {
          ProgressView()
            .frame(maxWidth: .infinity)
        } else if collectionViewModel.collections.isEmpty && searchText.isEmpty {
          Text("No collections found")
            .foregroundColor(.secondary)
        } else {
          Picker("Collection", selection: $selectedCollectionId) {
            ForEach(collectionViewModel.collections) { collection in
              Label(collection.name, systemImage: "square.grid.2x2").tag(collection.id as String?)
            }
          }
          .pickerStyle(.inline)
        }
      }
    } controls: {
      HStack(spacing: 12) {
        Button(action: confirmSelection) {
          Label("Done", systemImage: "checkmark")
        }
        .disabled(selectedCollectionId == nil)

        Button {
          showCreateSheet = true
        } label: {
          Label("Create New", systemImage: "plus.circle.fill")
        }
        .disabled(!isAdmin)
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
    SheetView(title: "Create Collection", size: .medium) {
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
        await MainActor.run {
          ErrorManager.shared.notify(message: "Collection created")
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
