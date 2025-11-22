//
//  CollectionPickerSheet.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct CollectionPickerSheet: View {
  @AppStorage("selectedLibraryId") private var selectedLibraryId: String = ""
  @Environment(\.dismiss) private var dismiss

  @State private var collectionViewModel = CollectionViewModel()
  @State private var selectedCollectionId: String?
  @State private var isLoading = false
  @State private var errorMessage: String?
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
    NavigationStack {
      Form {
        if isLoading && collectionViewModel.collections.isEmpty {
          ProgressView()
            .frame(maxWidth: .infinity)
        } else if let errorMessage = errorMessage {
          Text(errorMessage)
            .foregroundColor(.red)
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
      .navigationTitle("Select Collection")
      .navigationBarTitleDisplayMode(.inline)
      .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .automatic))
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          Button {
            if let selectedCollectionId = selectedCollectionId {
              onSelect(selectedCollectionId)
              dismiss()
            }
          } label: {
            Label("Done", systemImage: "checkmark")
          }
          .disabled(selectedCollectionId == nil)
        }
        ToolbarItem(placement: .navigationBarLeading) {
          Button {
            dismiss()
          } label: {
            Label("Cancel", systemImage: "xmark")
          }
        }
      }
      .toolbar {
        ToolbarItem(placement: .bottomBar) {
          Button {
            showCreateSheet = true
          } label: {
            Label("Create New", systemImage: "plus.circle.fill")
          }
          .disabled(!AppConfig.isAdmin)
        }
      }
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
          onCreate: { collectionId in
            // Create already adds series, so just complete and dismiss
            onComplete?()
            dismiss()
          }
        )
      }
    }
  }

  private func loadCollections(searchText: String = "") async {
    isLoading = true
    errorMessage = nil

    await collectionViewModel.loadCollections(
      libraryId: selectedLibraryId,
      sort: "name,asc",
      searchText: searchText,
      refresh: true
    )

    if let viewModelError = collectionViewModel.errorMessage {
      errorMessage = viewModelError
    }

    isLoading = false
  }
}

struct CreateCollectionSheet: View {
  @Environment(\.dismiss) private var dismiss
  @Binding var isCreating: Bool
  let seriesIds: [String]
  let onCreate: (String) -> Void

  @State private var name: String = ""
  @State private var errorMessage: String?

  var body: some View {
    NavigationStack {
      Form {
        Section {
          TextField("Collection Name", text: $name)
        }

        if let errorMessage = errorMessage {
          Section {
            Text(errorMessage)
              .foregroundColor(.red)
          }
        }
      }
      .navigationTitle("Create Collection")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          Button {
            dismiss()
          } label: {
            Label("Cancel", systemImage: "xmark")
          }
        }
        ToolbarItem(placement: .navigationBarTrailing) {
          Button {
            createCollection()
          } label: {
            if isCreating {
              ProgressView()
            } else {
              Label("Create", systemImage: "checkmark")
            }
          }
          .disabled(name.isEmpty || isCreating)
        }
      }
    }
  }

  private func createCollection() {
    guard !name.isEmpty else { return }

    isCreating = true
    errorMessage = nil

    Task {
      do {
        let collection = try await CollectionService.shared.createCollection(
          name: name,
          seriesIds: seriesIds
        )
        await MainActor.run {
          isCreating = false
          onCreate(collection.id)
          dismiss()
        }
      } catch {
        await MainActor.run {
          isCreating = false
          errorMessage = error.localizedDescription
        }
      }
    }
  }
}
