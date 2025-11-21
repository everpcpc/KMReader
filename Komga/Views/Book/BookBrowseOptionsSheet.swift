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
    NavigationStack {
      Form {
        Section("Filters") {
          Picker("Read Status", selection: $tempOpts.readStatusFilter) {
            ForEach(ReadStatusFilter.allCases, id: \.self) { filter in
              Text(filter.displayName).tag(filter)
            }
          }
          .pickerStyle(.menu)
        }

        Section("Sort") {
          Picker("Sort By", selection: $tempOpts.sortField) {
            ForEach(BookSortField.allCases, id: \.self) { field in
              Text(field.displayName).tag(field)
            }
          }
          .pickerStyle(.menu)

          if tempOpts.sortField.supportsDirection {
            Picker("Direction", selection: $tempOpts.sortDirection) {
              ForEach(SortDirection.allCases, id: \.self) { direction in
                HStack {
                  Image(systemName: direction.icon)
                  Text(direction.displayName)
                }
                .tag(direction)
              }
            }
            .pickerStyle(.menu)
          }
        }
      }
      .navigationTitle("Filter & Sort")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          Button {
            if tempOpts != browseOpts {
              browseOpts = tempOpts
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
