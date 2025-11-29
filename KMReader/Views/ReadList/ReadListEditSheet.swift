//
//  ReadListEditSheet.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct ReadListEditSheet: View {
  let readList: ReadList
  @Environment(\.dismiss) private var dismiss
  @State private var isSaving = false

  @State private var name: String
  @State private var summary: String
  @State private var ordered: Bool

  init(readList: ReadList) {
    self.readList = readList
    _name = State(initialValue: readList.name)
    _summary = State(initialValue: readList.summary)
    _ordered = State(initialValue: readList.ordered)
  }

  var body: some View {
    NavigationStack {
      Form {
        Section("Basic Information") {
          TextField("Name", text: $name)
          TextField("Summary", text: $summary, axis: .vertical)
            .lineLimit(3...10)
          Toggle("Ordered", isOn: $ordered)
        }
      }
      .inlineNavigationBarTitle("Edit Read List")
      .toolbar {
        ToolbarItem(placement: .automatic) {
          Button {
            dismiss()
          } label: {
            Label("Cancel", systemImage: "xmark")
          }
        }
        ToolbarItem(placement: .automatic) {
          Button {
            saveChanges()
          } label: {
            if isSaving {
              ProgressView()
            } else {
              Label("Save", systemImage: "checkmark")
            }
          }
          .disabled(isSaving || name.isEmpty)
        }
      }
    }
    #if canImport(UIKit)
      .presentationDetents([.medium])
    #else
      .frame(minWidth: 400, minHeight: 350)
    #endif
  }

  private func saveChanges() {
    isSaving = true
    Task {
      do {
        var hasChanges = false
        var nameToUpdate: String? = nil
        var summaryToUpdate: String? = nil
        var orderedToUpdate: Bool? = nil

        if name != readList.name {
          nameToUpdate = name
          hasChanges = true
        }
        if summary != readList.summary {
          summaryToUpdate = summary
          hasChanges = true
        }
        if ordered != readList.ordered {
          orderedToUpdate = ordered
          hasChanges = true
        }

        if hasChanges {
          try await ReadListService.shared.updateReadList(
            readListId: readList.id,
            name: nameToUpdate,
            summary: summaryToUpdate,
            ordered: orderedToUpdate
          )
          await MainActor.run {
            ErrorManager.shared.notify(message: "Read list updated")
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
