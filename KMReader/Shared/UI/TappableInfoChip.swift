//
// TappableInfoChip.swift
//
//

import SwiftUI

/// A tappable version of InfoChip that can navigate to a destination
struct TappableInfoChip: View {
  private let label: String
  let systemImage: String?
  let color: Color
  let destination: NavDestination

  init(
    label: String,
    systemImage: String? = nil,
    color: Color = .accentColor,
    destination: NavDestination
  ) {
    self.label = label
    self.systemImage = systemImage
    self.color = color
    self.destination = destination
  }

  var body: some View {
    NavigationLink(value: destination) {
      HStack(spacing: 4) {
        if let systemImage = systemImage {
          Image(systemName: systemImage)
            .font(.caption2)
        }
        Text(label)
          .font(.caption)
          .lineLimit(1)
      }
    }
    .adaptiveButtonStyle(.bordered)
    .controlSize(.mini)
    .tint(color)
  }
}
