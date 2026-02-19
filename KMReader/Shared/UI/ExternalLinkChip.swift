//
// ExternalLinkChip.swift
//
//

import SwiftUI

/// A chip for external URLs that matches the style of TappableInfoChip
struct ExternalLinkChip: View {
  let label: String
  let url: String
  var color: Color = .accentColor

  var body: some View {
    if let destination = URL(string: url) {
      Link(destination: destination) {
        labelView
      }
      .adaptiveButtonStyle(.bordered)
      .controlSize(.mini)
      .tint(color)
    } else {
      labelView
        .font(.caption)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(8)
        .foregroundColor(.secondary)
    }
  }

  private var labelView: some View {
    HStack(spacing: 4) {
      Image(systemName: "link")
        .font(.caption2)
      Text(label)
        .font(.caption)
        .lineLimit(1)
    }
  }
}
