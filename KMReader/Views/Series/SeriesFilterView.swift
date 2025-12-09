//
//  SeriesFilterView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct SeriesFilterView: View {
  @Binding var browseOpts: SeriesBrowseOptions
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

          if browseOpts.seriesStatusFilter != .all {
            FilterChip(
              label: browseOpts.seriesStatusFilter.displayName,
              systemImage: "chart.bar",
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
      SeriesBrowseOptionsSheet(browseOpts: $browseOpts)
    }
  }
}
