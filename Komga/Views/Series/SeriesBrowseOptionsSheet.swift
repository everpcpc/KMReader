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

        Section("Sort") {
          Picker("Sort By", selection: $tempOpts.sortField) {
            ForEach(SeriesSortField.allCases, id: \.self) { field in
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
