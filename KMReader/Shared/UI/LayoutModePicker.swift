//
//  LayoutModePicker.swift
//  Komga
//
//

import SwiftUI

struct LayoutModePicker: View {
  @Binding var selection: BrowseLayoutMode
  var showGridDensity: Bool = false

  @AppStorage("gridDensity") private var gridDensity: Double = GridDensity.standard.rawValue

  private var gridDensityBinding: Binding<GridDensity> {
    Binding(
      get: { GridDensity.closest(to: gridDensity) },
      set: { gridDensity = $0.rawValue }
    )
  }

  var body: some View {
    Picker(selection: $selection) {
      ForEach(BrowseLayoutMode.allCases) { mode in
        Label(mode.displayName, systemImage: mode.iconName)
          .tag(mode)
      }
    } label: {
      Label(
        String(localized: "Layout"),
        systemImage: selection.iconName
      )
    }.pickerStyle(.menu)

    if showGridDensity && selection == .grid {
      Picker(selection: gridDensityBinding) {
        ForEach(GridDensity.allCases, id: \.self) { density in
          Text(density.label).tag(density)
        }
      } label: {
        Label(
          String(localized: "settings.appearance.gridDensity.label"),
          systemImage: GridDensity.icon
        )
      }.pickerStyle(.menu)
    }
  }
}
