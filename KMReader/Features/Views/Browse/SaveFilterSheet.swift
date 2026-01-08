//
//  SaveFilterSheet.swift
//  KMReader
//
//  Created by Komga iOS Client
//

import SwiftData
import SwiftUI

struct SaveFilterSheet: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.modelContext) private var modelContext

  let filterType: SavedFilterType
  let seriesOptions: SeriesBrowseOptions?
  let bookOptions: BookBrowseOptions?
  let collectionOptions: CollectionSeriesBrowseOptions?
  let readListOptions: ReadListBookBrowseOptions?

  @State private var filterName: String = ""
  @State private var isSaving: Bool = false

  init(
    filterType: SavedFilterType,
    seriesOptions: SeriesBrowseOptions? = nil,
    bookOptions: BookBrowseOptions? = nil,
    collectionOptions: CollectionSeriesBrowseOptions? = nil,
    readListOptions: ReadListBookBrowseOptions? = nil
  ) {
    self.filterType = filterType
    self.seriesOptions = seriesOptions
    self.bookOptions = bookOptions
    self.collectionOptions = collectionOptions
    self.readListOptions = readListOptions
  }

  var body: some View {
    SheetView(
      title: String(localized: "Save Filter"),
      size: .medium,
      applyFormStyle: true
    ) {
      Form {
        Section {
          TextField("Filter Name", text: $filterName)
            .textFieldStyle(.plain)
        } header: {
          Text("Name")
        }

        Section {
          LabeledContent("Type", value: filterType.displayName)
        }
      }

    } controls: {
      Button(action: saveFilter) {
        if isSaving {
          ProgressView()
        } else {
          Label("Save Filter", systemImage: "checkmark")
        }
      }
      .disabled(filterName.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
    }
  }

  func saveFilter() {
    let trimmedName = filterName.trimmingCharacters(in: .whitespaces)
    guard !trimmedName.isEmpty else { return }

    isSaving = true

    guard
      let savedFilter = SavedFilter.create(
        name: trimmedName,
        filterType: filterType,
        seriesOptions: seriesOptions,
        bookOptions: bookOptions,
        collectionOptions: collectionOptions,
        readListOptions: readListOptions
      )
    else {
      ErrorManager.shared.alert(message: "Failed to create filter")
      isSaving = false
      return
    }

    modelContext.insert(savedFilter)

    do {
      try modelContext.save()
      dismiss()
    } catch {
      ErrorManager.shared.alert(error: error)
      isSaving = false
    }
  }
}
