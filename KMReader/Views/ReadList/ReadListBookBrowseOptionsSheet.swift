//
//  ReadListBookBrowseOptionsSheet.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct ReadListBookBrowseOptionsSheet: View {
  @Binding var browseOpts: ReadListBookBrowseOptions
  @Environment(\.dismiss) private var dismiss
  @State private var tempOpts: ReadListBookBrowseOptions

  init(browseOpts: Binding<ReadListBookBrowseOptions>) {
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
      tempOpts = ReadListBookBrowseOptions()
    }
  }

  private func applyChanges() {
    if tempOpts != browseOpts {
      browseOpts = tempOpts
    }
    dismiss()
  }
}
