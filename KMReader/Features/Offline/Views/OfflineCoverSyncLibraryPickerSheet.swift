//
// OfflineCoverSyncLibraryPickerSheet.swift
//
//

import SwiftUI

struct OfflineCoverSyncLibraryPickerSheet: View {
  let libraries: [LibraryInfo]
  let onApply: (Set<String>) -> Void

  @Environment(\.dismiss) private var dismiss
  @State private var draftSelectedLibraryIds: Set<String>
  @State private var didApplySelection = false

  init(
    libraries: [LibraryInfo],
    selectedLibraryIds: Set<String>,
    onApply: @escaping (Set<String>) -> Void
  ) {
    self.libraries = libraries
    self.onApply = onApply
    _draftSelectedLibraryIds = State(initialValue: selectedLibraryIds)
  }

  var body: some View {
    SheetView(
      title: String(
        localized: "offline.coverSync.scope.label",
        defaultValue: "Cover Sync Libraries"
      ),
      showsCloseButton: false,
      applyFormStyle: true
    ) {
      Form {
        Section {
          OfflineCoverSyncLibraryPickerRow(
            title: String(localized: "offline.coverSync.scope.all", defaultValue: "All Libraries"),
            isSelected: draftSelectedLibraryIds.isEmpty
          ) {
            draftSelectedLibraryIds.removeAll()
          }

          ForEach(libraries) { library in
            OfflineCoverSyncLibraryPickerRow(
              title: library.name,
              isSelected: draftSelectedLibraryIds.contains(library.id)
            ) {
              toggleLibrary(library.id)
            }
          }
        }
      }
    } controls: {
      Button(String(localized: "Done")) {
        applySelection()
        dismiss()
      }
    }
    .onDisappear {
      applySelection()
    }
  }

  private func toggleLibrary(_ libraryId: String) {
    if draftSelectedLibraryIds.contains(libraryId) {
      draftSelectedLibraryIds.remove(libraryId)
    } else {
      draftSelectedLibraryIds.insert(libraryId)
    }
  }

  private func normalizedSelection() -> Set<String> {
    let validLibraryIds = Set(libraries.map(\.id))
    let selectedLibraryIds = draftSelectedLibraryIds.intersection(validLibraryIds)
    if selectedLibraryIds.count == validLibraryIds.count {
      return []
    }
    return selectedLibraryIds
  }

  private func applySelection() {
    guard !didApplySelection else { return }
    didApplySelection = true
    onApply(normalizedSelection())
  }
}
