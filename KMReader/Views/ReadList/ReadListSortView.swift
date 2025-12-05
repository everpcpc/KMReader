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

  var body: some View {
    HStack(spacing: 8) {
      LayoutModePicker()

      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 6) {
          Image(systemName: "arrow.up.arrow.down.circle")
            .padding(.leading, 4)

          Button {
            showFilterSheet = true
          } label: {
            FilterChip(
              label:
                "\(sortOpts.sortField.displayName) \(sortOpts.sortDirection == .ascending ? "↑" : "↓")",
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
      SimpleSortOptionsSheet(sortOpts: $sortOpts)
    }
  }
}
