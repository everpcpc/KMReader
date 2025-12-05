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

      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 6) {
          Image(systemName: "line.3.horizontal.decrease.circle")
            .padding(.leading, 4)

          if browseOpts.readStatusFilter != .all {
            Button {
              showFilterSheet = true
            } label: {
              FilterChip(
                label: "Read: \(browseOpts.readStatusFilter.displayName)",
                systemImage: "eye"
              )
            }
            .buttonStyle(.plain)
          }

          Button {
            showFilterSheet = true
          } label: {
            FilterChip(
              label:
                "\(browseOpts.sortField.displayName) \(browseOpts.sortDirection == .ascending ? "↑" : "↓")",
              systemImage: "arrow.up.arrow.down"
            )
          }
          .buttonStyle(.plain)
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
