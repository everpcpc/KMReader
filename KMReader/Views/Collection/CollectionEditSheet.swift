//
//  CollectionEditSheet.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct CollectionEditSheet: View {
  let collection: KomgaCollection
  @Environment(\.dismiss) private var dismiss
  @State private var isSaving = false

  @State private var name: String
  @State private var ordered: Bool

  init(collection: KomgaCollection) {
    self.collection = collection
    _name = State(initialValue: collection.name)
    _ordered = State(initialValue: collection.ordered)
  }

  var body: some View {
    SheetView(title: "Edit Collection", size: .medium) {
        Form {
          Section("Basic Information") {
            TextField("Name", text: $name)
            Toggle("Ordered", isOn: $ordered)
          }
        }
      }
    controls: {
      Button(action: saveChanges) {
        if isSaving {
          ProgressView()
        } else {
          Label("Save", systemImage: "checkmark")
        }
      }
      .disabled(isSaving || name.isEmpty)
    }
  }

  private func saveChanges() {
    isSaving = true
    Task {
      do {
        var hasChanges = false
        var nameToUpdate: String? = nil
        var orderedToUpdate: Bool? = nil

        if name != collection.name {
          nameToUpdate = name
          hasChanges = true
        }
        if ordered != collection.ordered {
          orderedToUpdate = ordered
          hasChanges = true
        }

        if hasChanges {
          try await CollectionService.shared.updateCollection(
            collectionId: collection.id,
            name: nameToUpdate,
            ordered: orderedToUpdate
          )
          await MainActor.run {
            ErrorManager.shared.notify(message: "Collection updated")
            dismiss()
          }
        } else {
          await MainActor.run {
            dismiss()
          }
        }
      } catch {
        await MainActor.run {
          ErrorManager.shared.alert(error: error)
        }
      }
      await MainActor.run {
        isSaving = false
      }
    }
  }
}
