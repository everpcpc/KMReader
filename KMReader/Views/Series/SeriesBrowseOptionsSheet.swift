//
//  SeriesBrowseOptionsSheet.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct SeriesBrowseOptionsSheet: View {
  @Binding var browseOpts: SeriesBrowseOptions
  @Environment(\.dismiss) private var dismiss
  @State private var tempOpts: SeriesBrowseOptions

  init(browseOpts: Binding<SeriesBrowseOptions>) {
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

          Picker("Series Status", selection: $tempOpts.seriesStatusFilter) {
            ForEach(SeriesStatusFilter.allCases, id: \.self) { filter in
              Text(filter.displayName).tag(filter)
            }
          }
          .pickerStyle(.menu)
        }

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
      .inlineNavigationBarTitle("Filter & Sort")
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
    if tempOpts != browseOpts {
      browseOpts = tempOpts
    }
    dismiss()
  }
}
