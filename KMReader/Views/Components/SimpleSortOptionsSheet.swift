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
      .inlineNavigationBarTitle("Sort")
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
    #if canImport(UIKit)
      .presentationDetents([.medium])
    #else
      .frame(minWidth: 400, minHeight: 300)
    #endif
  }
}
