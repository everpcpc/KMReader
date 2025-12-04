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

      Button {
        showFilterSheet = true
      } label: {
        Image(systemName: "arrow.up.arrow.down.circle")
          .imageScale(.large)
      }
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 6) {
          FilterChip(
            label:
              "\(sortOpts.sortField.displayName) \(sortOpts.sortDirection == .ascending ? "↑" : "↓")",
            systemImage: "arrow.up.arrow.down"
          )
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
