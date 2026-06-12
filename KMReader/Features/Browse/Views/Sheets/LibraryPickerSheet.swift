//
// LibraryPickerSheet.swift
//
//

import SwiftUI

struct LibraryPickerSheet: View {
  @Environment(\.dismiss) private var dismiss
  @AppStorage("libraryPickerSingleSelection") private var isSingleSelectionMode = false
  @State private var refreshTrigger = 0

  var body: some View {
    SheetView(title: String(localized: "Libraries"), size: .large, applyFormStyle: true) {
      LibraryListContent(
        selectionEnabled: true,
        isSingleSelectionMode: isSingleSelectionMode,
        forceMetricsOnAppear: false,
        enablePullToRefresh: false,
        onLibrarySelected: { _ in
          guard isSingleSelectionMode else { return }
          dismiss()
        },
        refreshTrigger: refreshTrigger
      )
    } controls: {
      HStack(spacing: 12) {
        Button {
          isSingleSelectionMode.toggle()
        } label: {
          Label(
            isSingleSelectionMode
              ? String(localized: "library.picker.mode.single", defaultValue: "Single Select")
              : String(localized: "library.picker.mode.multiple", defaultValue: "Multiple Select"),
            systemImage: isSingleSelectionMode ? "largecircle.fill.circle" : "checklist"
          )
        }

        Button {
          refreshTrigger += 1
        } label: {
          Label("Refresh", systemImage: "arrow.clockwise")
        }
      }
    }
  }
}
