//
// SavedFiltersView.swift
//
//

import Dependencies
import SQLiteData
import SwiftUI

struct SavedFiltersView: View {
  @Environment(\.dismiss) private var dismiss
  @Dependency(\.defaultDatabase) private var database
  @FetchAll(SavedFilterRecord.order { $0.updatedAt.desc() }) private var savedFilters: [SavedFilterRecord]

  let filterType: SavedFilterType
  @State private var filterToRename: SavedFilterRecord?
  @State private var newName: String = ""

  var body: some View {
    SheetView(
      title: String(localized: "Saved Filters"),
      size: .medium,
      applyFormStyle: true
    ) {
      let displayFilters = savedFilters.filter { $0.filterType == filterType }

      if displayFilters.isEmpty {
        ContentUnavailableView {
          Label("No Saved Filters", systemImage: "bookmark.slash")
        } description: {
          Text(
            "Save your frequently used \(filterType.displayName.lowercased()) filters for quick access"
          )
        }
      } else {
        List {
          Section(filterType.displayName) {
            ForEach(displayFilters) { filter in
              filterRow(filter)
            }
          }
        }
      }
    }
    .alert(
      "Rename Filter",
      isPresented: .init(
        get: { filterToRename != nil },
        set: { if !$0 { filterToRename = nil } }
      )
    ) {
      TextField("Filter Name", text: $newName)
      Button("Cancel", role: .cancel) {
        filterToRename = nil
        newName = ""
      }
      Button("Rename") {
        if let filter = filterToRename {
          renameFilter(filter, to: newName)
        }
      }
    }
  }

  @ViewBuilder
  private func filterRow(_ filter: SavedFilterRecord) -> some View {
    HStack {
      VStack(alignment: .leading, spacing: 4) {
        Text(filter.name)
          .font(.body)
        Text(filter.updatedAt, style: .relative)
          .font(.caption)
          .foregroundColor(.secondary)
      }

      Spacer()

      Button {
        applyFilterDirectly(filter)
        dismiss()
      } label: {
        Image(systemName: "arrowshape.turn.up.forward")
          .foregroundColor(.accentColor)
      }
      .adaptiveButtonStyle(.plain)
    }
    #if !os(tvOS)
      .swipeActions(edge: .trailing, allowsFullSwipe: false) {
        Button(role: .destructive) {
          deleteFilter(filter)
        } label: {
          Label("Delete", systemImage: "trash")
        }

        Button {
          newName = filter.name
          filterToRename = filter
        } label: {
          Label("Rename", systemImage: "pencil")
        }
        .tint(.blue)
      }
    #endif
    .contextMenu {
      Button {
        applyFilterDirectly(filter)
        dismiss()
      } label: {
        Label("Apply Filter", systemImage: "arrowshape.turn.up.forward")
      }

      Button {
        newName = filter.name
        filterToRename = filter
      } label: {
        Label("Rename", systemImage: "pencil")
      }

      Divider()

      Button(role: .destructive) {
        deleteFilter(filter)
      } label: {
        Label("Delete", systemImage: "trash")
      }
    }
  }

  private func applyFilterDirectly(_ filter: SavedFilterRecord) {
    switch filter.filterType {
    case .series:
      if let options = filter.seriesOptions() {
        AppConfig.seriesBrowseOptions = options.rawValue
      }
    case .books:
      if let options = filter.bookOptions() {
        AppConfig.bookBrowseOptions = options.rawValue
      }
    case .collectionSeries:
      if let options = filter.collectionOptions() {
        AppConfig.collectionSeriesBrowseOptions = options.rawValue
      }
    case .readListBooks:
      if let options = filter.readListOptions() {
        AppConfig.readListBookBrowseOptions = options.rawValue
      }
    case .seriesBooks:
      if let options = filter.bookOptions() {
        AppConfig.seriesBookBrowseOptions = options.rawValue
      }
    }
  }

  private func deleteFilter(_ filter: SavedFilterRecord) {
    do {
      try database.write { db in
        try SavedFilterRecord.find(filter.id).delete().execute(db)
      }
    } catch {
      ErrorManager.shared.alert(message: "Failed to delete filter: \(error.localizedDescription)")
    }
  }

  private func renameFilter(_ filter: SavedFilterRecord, to newName: String) {
    let trimmed = newName.trimmingCharacters(in: .whitespaces)
    guard !trimmed.isEmpty else { return }
    let now = Date()

    do {
      try database.write { db in
        try SavedFilterRecord
          .find(filter.id)
          .update {
            $0.name = #bind(trimmed)
            $0.updatedAt = #bind(now)
          }
          .execute(db)
      }

      filterToRename = nil
      self.newName = ""
    } catch {
      ErrorManager.shared.alert(message: "Failed to rename filter: \(error.localizedDescription)")
    }
  }
}
