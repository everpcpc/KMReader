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
      // The blank caption-text line keeps the button as tall as sibling FilterChips,
      // whose height comes from their caption text rather than the icon.
      ZStack {
        Text(verbatim: " ")
          .font(.caption)
          .fontWeight(.medium)
          .accessibilityHidden(true)
        Label(selection.displayName, systemImage: selection.iconName)
          .labelStyle(.iconOnly)
          .font(.caption)
      }
      .frame(width: 16)
    }
    .fixedSize()
    .adaptiveButtonStyle(.bordered)
    .optimizedControlSize()
  }
}
