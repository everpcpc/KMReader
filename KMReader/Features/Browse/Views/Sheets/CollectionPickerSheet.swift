//
//  CollectionPickerSheet.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftData
import SwiftUI

private struct CollectionItem: Identifiable {
  let id: String
  let name: String
  let alreadyIn: Bool
}

struct CollectionPickerSheet: View {
  @Environment(\.dismiss) private var dismiss
  @AppStorage("currentAccount") private var current: Current = .init()

  @State private var selectedCollectionId: String?
  @State private var isLoading = false
  @State private var searchText: String = ""
  @State private var showCreateSheet = false
  @State private var isCreating = false

  @Query private var komgaCollections: [KomgaCollection]

  let seriesId: String
  let onSelect: (String) -> Void

  init(
    seriesId: String,
    onSelect: @escaping (String) -> Void
  ) {
    self.seriesId = seriesId
    self.onSelect = onSelect

    let instanceId = AppConfig.current.instanceId
    _komgaCollections = Query(
      filter: #Predicate<KomgaCollection> { $0.instanceId == instanceId },
      sort: [SortDescriptor(\KomgaCollection.name, order: .forward)]
    )
  }

  private var filteredCollections: [KomgaCollection] {
    if searchText.isEmpty {
      return Array(komgaCollections)
    }
    return komgaCollections.filter {
      $0.name.localizedCaseInsensitiveContains(searchText)
    }
  }

  private var collectionItems: [CollectionItem] {
    filteredCollections.map { collection in
      CollectionItem(
        id: collection.collectionId,
        name: collection.name,
        alreadyIn: collection.seriesIds.contains(seriesId)
      )
    }
  }

  var body: some View {
    SheetView(title: String(localized: "Select Collection"), size: .large, applyFormStyle: true) {
      Form {
        if isLoading && komgaCollections.isEmpty {
          LoadingIcon()
            .frame(maxWidth: .infinity)
        } else if filteredCollections.isEmpty && searchText.isEmpty {
          Text("No collections found")
            .foregroundColor(.secondary)
        } else {
          Section {
            ForEach(collectionItems) { item in
              Button {
                if !item.alreadyIn {
                  selectedCollectionId = item.id
                }
              } label: {
                HStack {
                  Label(item.name, systemImage: ContentIcon.collection)
                  Spacer()
                  if item.alreadyIn {
                    Image(systemName: "checkmark.circle.fill")
                      .foregroundStyle(.green)
                  } else if selectedCollectionId == item.id {
                    Image(systemName: "checkmark")
                      .foregroundStyle(.tint)
                  }
                }
                .foregroundStyle(item.alreadyIn ? .secondary : .primary)
              }
              .disabled(item.alreadyIn)
            }
          }
        }
      }
    } controls: {
      Button {
        showCreateSheet = true
      } label: {
        Label("Create New", systemImage: "plus.circle.fill")
      }
      .disabled(!current.isAdmin)

      HStack(spacing: 12) {
        Button(action: confirmSelection) {
          Label("Done", systemImage: "checkmark")
        }
        .disabled(selectedCollectionId == nil)
      }
    }
    .searchable(text: $searchText)
    .task {
      await syncCollections()
    }
    .sheet(isPresented: $showCreateSheet) {
      CreateCollectionSheet(
        isCreating: $isCreating,
        seriesId: seriesId,
        onCreate: { _ in
          dismiss()
        }
      )
    }
  }

  private func syncCollections() async {
    guard !AppConfig.isOffline else { return }
    isLoading = true
    await SyncService.shared.syncCollections(instanceId: current.instanceId)
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
  let seriesId: String
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
          LoadingIcon()
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
          seriesIds: [seriesId]
        )
        // Sync the collection to update its seriesIds in local SwiftData
        _ = try? await SyncService.shared.syncCollection(id: collection.id)
        ErrorManager.shared.notify(message: String(localized: "notification.collection.created"))
        isCreating = false
        onCreate(collection.id)
        dismiss()
      } catch {
        isCreating = false
        ErrorManager.shared.alert(error: error)
      }
    }
  }
}
