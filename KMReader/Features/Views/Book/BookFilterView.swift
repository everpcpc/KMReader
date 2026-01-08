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

  init(
    browseOpts: Binding<BookBrowseOptions>,
    showFilterSheet: Binding<Bool>,
    showSavedFilters: Binding<Bool>,
    filterType: SavedFilterType = .books
  ) {
    self._browseOpts = browseOpts
    self._showFilterSheet = showFilterSheet
    self._showSavedFilters = showSavedFilters
    self.filterType = filterType
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
      }
      .padding(4)
    }
    .scrollClipDisabled()
    .sheet(isPresented: $showFilterSheet) {
      BookBrowseOptionsSheet(browseOpts: $browseOpts, filterType: filterType)
    }
  }
}
