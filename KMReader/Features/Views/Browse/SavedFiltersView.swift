//
//  SavedFiltersView.swift
//  KMReader
//
//  Created by Komga iOS Client
//

import SwiftData
import SwiftUI

struct SavedFiltersView: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.modelContext) private var modelContext
  @Query(sort: \SavedFilter.updatedAt, order: .reverse) private var savedFilters: [SavedFilter]

  let filterType: SavedFilterType
  @State private var filterToRename: SavedFilter?
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
  private func filterRow(_ filter: SavedFilter) -> some View {
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
        Image(systemName: "line.3.horizontal.decrease.circle.fill")
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
        Label("Apply Filter", systemImage: "line.3.horizontal.decrease.circle.fill")
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

  private func applyFilterDirectly(_ filter: SavedFilter) {
    switch filter.filterType {
    case .series:
      if let options = filter.getSeriesBrowseOptions() {
        AppConfig.seriesBrowseOptions = options.rawValue
      }
    case .books:
      if let options = filter.getBookBrowseOptions() {
        AppConfig.bookBrowseOptions = options.rawValue
      }
    case .collectionSeries:
      if let options = filter.getCollectionSeriesBrowseOptions() {
        AppConfig.collectionSeriesBrowseOptions = options.rawValue
      }
    case .readListBooks:
      if let options = filter.getReadListBookBrowseOptions() {
        AppConfig.readListBookBrowseOptions = options.rawValue
      }
    case .seriesBooks:
      if let options = filter.getBookBrowseOptions() {
        AppConfig.seriesBookBrowseOptions = options.rawValue
      }
    }
  }

  private func deleteFilter(_ filter: SavedFilter) {
    modelContext.delete(filter)
    try? modelContext.save()
  }

  private func renameFilter(_ filter: SavedFilter, to newName: String) {
    let trimmed = newName.trimmingCharacters(in: .whitespaces)
    guard !trimmed.isEmpty else { return }

    filter.name = trimmed
    filter.updatedAt = Date()
    try? modelContext.save()

    filterToRename = nil
    self.newName = ""
  }
}
