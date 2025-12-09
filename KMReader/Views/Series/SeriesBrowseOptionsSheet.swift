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
    SheetView(
      title: String(localized: "Filter & Sort"), size: .both, onReset: resetOptions,
      applyFormStyle: true
    ) {
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

      }
    } controls: {
      Button(action: applyChanges) {
        Label("Done", systemImage: "checkmark")
      }
    }
  }

  private func resetOptions() {
    withAnimation {
      tempOpts = SeriesBrowseOptions()
    }
  }

  private func applyChanges() {
    if tempOpts != browseOpts {
      browseOpts = tempOpts
    }
    dismiss()
  }
}
