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

        #if os(tvOS)
          Section {
            Button(action: applyChanges) {
              Label("Done", systemImage: "checkmark")
            }
          }
          .listRowBackground(Color.clear)
        #endif
      }
      .padding(PlatformHelper.sheetPadding)
      .inlineNavigationBarTitle("Sort")
      #if !os(tvOS)
        .toolbar {
          ToolbarItem(placement: .automatic) {
            Button(action: applyChanges) {
              Label("Done", systemImage: "checkmark")
            }
          }
        }
      #endif
    }
    .platformSheetPresentation(detents: [.medium])
  }

  private func applyChanges() {
    if tempOpts != sortOpts {
      sortOpts = tempOpts
    }
    dismiss()
  }
}
