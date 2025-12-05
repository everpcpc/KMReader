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
    SheetView(title: "Filter", size: .both, applyFormStyle: true) {
      Form {
        Section("Filters") {
          Picker("Read Status", selection: $tempOpts.readStatusFilter) {
            ForEach(ReadStatusFilter.allCases, id: \.self) { filter in
              Text(filter.displayName).tag(filter)
            }
          }
          .pickerStyle(.menu)
        }

        Section {
          Button(action: resetOptions) {
            Label("Reset", systemImage: "arrow.counterclockwise")
          }
        }
      }
    } controls: {
      Button(action: applyChanges) {
        Label("Done", systemImage: "checkmark")
      }
    }
  }

  private func resetOptions() {
    tempOpts = ReadListBookBrowseOptions()
  }

  private func applyChanges() {
    if tempOpts != browseOpts {
      browseOpts = tempOpts
    }
    dismiss()
  }
}
