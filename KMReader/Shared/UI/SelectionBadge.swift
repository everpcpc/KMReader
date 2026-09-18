//
// SelectionBadge.swift
//
//

import SwiftUI

/// Selection-mode checkbox: a gray outline circle that turns into a filled
/// accent checkmark when selected. `onCover` renders the badge legibly on top
/// of artwork (white on a dark scrim), like Photos.
struct SelectionBadge: View {
  let isSelected: Bool
  var onCover: Bool = false

  var body: some View {
    if onCover {
      ZStack {
        if !isSelected {
          Image(systemName: "circle.fill")
            .foregroundStyle(.black.opacity(0.35))
        }
        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
          .symbolRenderingMode(.palette)
          .foregroundStyle(.white, Color.accentColor)
      }
      .font(.title3)
      .padding(8)
    } else {
      Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
        .font(.title3)
        .foregroundStyle(isSelected ? Color.accentColor : Color.secondary.opacity(0.5))
    }
  }
}
