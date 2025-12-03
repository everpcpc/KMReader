//
//  BookBrowseOptionsSheet.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct BookBrowseOptionsSheet: View {
  @Binding var browseOpts: BookBrowseOptions
  @Environment(\.dismiss) private var dismiss
  @State private var tempOpts: BookBrowseOptions

  init(browseOpts: Binding<BookBrowseOptions>) {
    self._browseOpts = browseOpts
    self._tempOpts = State(initialValue: browseOpts.wrappedValue)
  }

  var body: some View {
    SheetView(title: "Filter & Sort", size: .medium) {
        Form {
          Section("Filters") {
            Picker("Read Status", selection: $tempOpts.readStatusFilter) {
              ForEach(ReadStatusFilter.allCases, id: \.self) { filter in
                Text(filter.displayName).tag(filter)
              }
            }
            .pickerStyle(.menu)
          }

          SortOptionView(
            sortField: $tempOpts.sortField,
            sortDirection: $tempOpts.sortDirection
          )
        }
    }
    controls: {
      Button(action: applyChanges) {
        Label("Done", systemImage: "checkmark")
      }
    }
  }

  private func applyChanges() {
    if tempOpts != browseOpts {
      browseOpts = tempOpts
    }
    dismiss()
  }
}
