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

  var body: some View {
    HStack(spacing: 8) {
      LayoutModePicker()

      Button {
        showFilterSheet = true
      } label: {
        Image(systemName: "line.3.horizontal.decrease.circle")
          .imageScale(.large)
      }
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 6) {
          if browseOpts.readStatusFilter != .all {
            FilterChip(
              label: "Read: \(browseOpts.readStatusFilter.displayName)",
              systemImage: "eye"
            )
          }

          FilterChip(
            label:
              "\(browseOpts.sortField.displayName) \(browseOpts.sortDirection == .ascending ? "↑" : "↓")",
            systemImage: "arrow.up.arrow.down"
          )
        }
        .padding(.horizontal, 4)
      }

      Spacer()
    }
    .sheet(isPresented: $showFilterSheet) {
      BookBrowseOptionsSheet(browseOpts: $browseOpts)
    }
  }
}
