//
// LayoutModeToggleButton.swift
//
//

import SwiftUI

struct LayoutModeToggleButton: View {
  @Binding var selection: BrowseLayoutMode

  var body: some View {
    Button {
      selection = selection == .grid ? .list : .grid
    } label: {
      Label(selection.displayName, systemImage: selection.iconName)
        .labelStyle(.iconOnly)
        .font(.caption)
        .frame(width: 16)
    }
    .fixedSize()
    .adaptiveButtonStyle(.bordered)
    .optimizedControlSize()
  }
}
