//
//  BookFilterView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct BookFilterView: View {
  @Binding var browseOpts: BookBrowseOptions
  @Binding var showFilterSheet: Bool
  @Binding var showSavedFilters: Bool
  let filterType: SavedFilterType
  let seriesId: String?
  let libraryIds: [String]?

  init(
    browseOpts: Binding<BookBrowseOptions>,
    showFilterSheet: Binding<Bool>,
    showSavedFilters: Binding<Bool>,
    filterType: SavedFilterType = .books,
    seriesId: String? = nil,
    libraryIds: [String]? = nil
  ) {
    self._browseOpts = browseOpts
    self._showFilterSheet = showFilterSheet
    self._showSavedFilters = showSavedFilters
    self.filterType = filterType
    self.seriesId = seriesId
    self.libraryIds = libraryIds
  }

  var sortString: String {
    return
      "\(browseOpts.sortField.displayName) \(browseOpts.sortDirection == .ascending ? "↑" : "↓")"
  }

  var body: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 6) {
        FilterChip(
          label: String(localized: "Presets"),
          systemImage: "bookmark",
          variant: .preset,
          openSheet: $showSavedFilters
        )

        FilterChip(
          label: sortString,
          systemImage: "arrow.up.arrow.down",
          openSheet: $showFilterSheet
        )

        if let label = buildReadStatusLabel(
          include: browseOpts.includeReadStatuses,
          exclude: browseOpts.excludeReadStatuses
        ) {
          FilterChip(
            label: label,
            systemImage: "eye",
            variant: label.contains("≠") ? .negative : .normal,
            openSheet: $showFilterSheet
          )
        }

        if browseOpts.oneshotFilter.isActive,
          let label = browseOpts.oneshotFilter.displayLabel(using: { _ in FilterStrings.oneshot })
        {
          FilterChip(
            label: label,
            systemImage: "dot.circle",
            variant: browseOpts.oneshotFilter.state == .exclude ? .negative : .normal,
            openSheet: $showFilterSheet
          )
        }

        if browseOpts.deletedFilter.isActive,
          let label = browseOpts.deletedFilter.displayLabel(using: { _ in FilterStrings.deleted })
        {
          FilterChip(
            label: label,
            systemImage: "trash",
            variant: browseOpts.deletedFilter.state == .exclude ? .negative : .normal,
            openSheet: $showFilterSheet
          )
        }

        if let authors = browseOpts.metadataFilter.authors, !authors.isEmpty {
          let logicSymbol = browseOpts.metadataFilter.authorsLogic == .all ? "∧" : "∨"
          let label = authors.joined(separator: " \(logicSymbol) ")
          FilterChip(
            label: label,
            systemImage: "person",
            openSheet: $showFilterSheet
          )
        }

        if let tags = browseOpts.metadataFilter.tags, !tags.isEmpty {
          let logicSymbol = browseOpts.metadataFilter.tagsLogic == .all ? "∧" : "∨"
          let label = tags.joined(separator: " \(logicSymbol) ")
          FilterChip(
            label: label,
            systemImage: "tag",
            openSheet: $showFilterSheet
          )
        }

      }
      .padding(4)
    }
    .scrollClipDisabled()
    .sheet(isPresented: $showFilterSheet) {
      BookBrowseOptionsSheet(
        browseOpts: $browseOpts, filterType: filterType, seriesId: seriesId, libraryIds: libraryIds)
    }
  }
}
