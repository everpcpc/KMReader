//
//  SimpleSortOptionsSheet.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct SimpleSortOptionsSheet: View {
  @Binding var sortOpts: SimpleSortOptions
  @Environment(\.dismiss) private var dismiss
  @State private var tempOpts: SimpleSortOptions

  init(sortOpts: Binding<SimpleSortOptions>) {
    self._sortOpts = sortOpts
    self._tempOpts = State(initialValue: sortOpts.wrappedValue)
  }

  var body: some View {
    NavigationStack {
      Form {
        SortOptionView(
          sortField: $tempOpts.sortField,
          sortDirection: $tempOpts.sortDirection
        )
      }
      .navigationTitle("Sort")
      #if canImport(UIKit)
        .navigationBarTitleDisplayMode(.inline)
      #endif
      .toolbar {
        ToolbarItem(placement: .automatic) {
          Button {
            if tempOpts != sortOpts {
              sortOpts = tempOpts
            }
            dismiss()
          } label: {
            Label("Done", systemImage: "checkmark")
          }
        }
      }
    }
  }
}
