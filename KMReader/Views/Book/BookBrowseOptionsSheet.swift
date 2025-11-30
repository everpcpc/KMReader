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

        SortOptionView(
          sortField: $tempOpts.sortField,
          sortDirection: $tempOpts.sortDirection
        )
      }
      .padding(PlatformHelper.sheetPadding)
      .inlineNavigationBarTitle("Filter & Sort")
      .toolbar {
        ToolbarItem(placement: .automatic) {
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
    #if os(iOS)
      .presentationDetents([.medium])
    #else
      .frame(minWidth: 400, minHeight: 400)
    #endif
  }
}
