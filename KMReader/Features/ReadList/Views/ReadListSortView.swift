//
//  ReadListSortView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct ReadListSortView: View {
  @AppStorage("readListSortOptions") private var sortOpts: SimpleSortOptions =
    SimpleSortOptions()
  @Binding var showFilterSheet: Bool

  var sortString: String {
    return
      "\(sortOpts.sortField.displayName) \(sortOpts.sortDirection == .ascending ? "↑" : "↓")"
  }

  var body: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 6) {
        Image(systemName: "arrow.up.arrow.down.circle")
          .padding(.leading, 4)
          .foregroundColor(.secondary)

        FilterChip(
          label: sortString,
          systemImage: "arrow.up.arrow.down",
          openSheet: $showFilterSheet
        )
      }
      .padding(4)
    }
    .scrollClipDisabled()
    .sheet(isPresented: $showFilterSheet) {
      SimpleSortOptionsSheet(sortOpts: $sortOpts)
    }
  }
}
