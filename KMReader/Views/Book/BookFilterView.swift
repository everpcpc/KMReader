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
  @Binding var layoutMode: BrowseLayoutMode

  var sortString: String {
    return
      "\(browseOpts.sortField.displayName) \(browseOpts.sortDirection == .ascending ? "↑" : "↓")"
  }

  var body: some View {
    HStack(spacing: 8) {
      LayoutModePicker(selection: $layoutMode)

      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 6) {
          Image(systemName: "line.3.horizontal.decrease.circle")
            .padding(.leading, 4)
            .foregroundColor(.secondary)

          if browseOpts.readStatusFilter != .all {
            FilterChip(
              label: browseOpts.readStatusFilter.displayName,
              systemImage: "eye",
              openSheet: $showFilterSheet
            )
          }

          FilterChip(
            label: sortString,
            systemImage: "arrow.up.arrow.down",
            openSheet: $showFilterSheet
          )
        }
        .padding(4)
      }
      .scrollClipDisabled()
    }
    .sheet(isPresented: $showFilterSheet) {
      BookBrowseOptionsSheet(browseOpts: $browseOpts)
    }
  }
}
