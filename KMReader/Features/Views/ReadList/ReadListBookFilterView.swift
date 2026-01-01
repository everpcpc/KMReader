//
//  ReadListBookFilterView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct ReadListBookFilterView: View {
  @Binding var browseOpts: ReadListBookBrowseOptions
  @Binding var showFilterSheet: Bool

  var emptyFilter: Bool {
    return browseOpts.includeReadStatuses.isEmpty && browseOpts.excludeReadStatuses.isEmpty
  }

  var body: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 6) {
        Image(systemName: "line.3.horizontal.decrease.circle")
          .padding(.leading, 4)
          .foregroundColor(.secondary)

        if let label = readStatusLabel() {
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

        if emptyFilter {
          FilterChip(
            label: String(localized: "Filter"),
            systemImage: "line.3.horizontal.decrease.circle",
            openSheet: $showFilterSheet
          )
        }
      }
      .padding(4)
    }
    .scrollClipDisabled()
    .sheet(isPresented: $showFilterSheet) {
      ReadListBookBrowseOptionsSheet(browseOpts: $browseOpts)
    }
  }
}

extension ReadListBookFilterView {
  fileprivate func readStatusLabel() -> String? {
    buildReadStatusLabel(
      include: browseOpts.includeReadStatuses,
      exclude: browseOpts.excludeReadStatuses
    )
  }
}
