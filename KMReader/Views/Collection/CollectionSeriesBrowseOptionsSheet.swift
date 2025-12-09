//
//  CollectionSeriesBrowseOptionsSheet.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct CollectionSeriesBrowseOptionsSheet: View {
  @Binding var browseOpts: CollectionSeriesBrowseOptions
  @Environment(\.dismiss) private var dismiss
  @State private var tempOpts: CollectionSeriesBrowseOptions

  init(browseOpts: Binding<CollectionSeriesBrowseOptions>) {
    self._browseOpts = browseOpts
    self._tempOpts = State(initialValue: browseOpts.wrappedValue)
  }

  var body: some View {
    SheetView(
      title: String(localized: "Filter"), size: .both, onReset: resetOptions, applyFormStyle: true
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

      }
    } controls: {
      Button(action: applyChanges) {
        Label("Done", systemImage: "checkmark")
      }
    }
  }

  private func resetOptions() {
    withAnimation {
      tempOpts = CollectionSeriesBrowseOptions()
    }
  }

  private func applyChanges() {
    if tempOpts != browseOpts {
      browseOpts = tempOpts
    }
    dismiss()
  }
}
