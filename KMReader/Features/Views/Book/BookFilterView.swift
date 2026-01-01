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

  var sortString: String {
    return
      "\(browseOpts.sortField.displayName) \(browseOpts.sortDirection == .ascending ? "↑" : "↓")"
  }

  var body: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 6) {
        Image(systemName: "line.3.horizontal.decrease.circle")
          .padding(.leading, 4)
          .foregroundColor(.secondary)

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
      BookBrowseOptionsSheet(browseOpts: $browseOpts)
    }
  }
}
