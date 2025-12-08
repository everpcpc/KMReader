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
  @Binding var layoutMode: BrowseLayoutMode

  var emptyFilter: Bool {
    return browseOpts.readStatusFilter == .all
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
              label: "Read: \(browseOpts.readStatusFilter.displayName)",
              systemImage: "eye",
              openSheet: $showFilterSheet
            )
          }

          if emptyFilter {
            FilterChip(
              label: "Filter",
              systemImage: "line.3.horizontal.decrease.circle",
              openSheet: $showFilterSheet
            )
          }
        }
        .padding(4)
      }
      .scrollClipDisabled()
    }
    .sheet(isPresented: $showFilterSheet) {
      ReadListBookBrowseOptionsSheet(browseOpts: $browseOpts)
    }
  }
}
