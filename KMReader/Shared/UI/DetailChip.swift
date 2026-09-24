//
// DetailChip.swift
//
//

import SwiftUI

/// Outlined rounded-rect chip for detail-page metadata, in the spirit of
/// the Komga web UI's tags: one quiet neutral style, no per-field colors,
/// no filled backgrounds.
struct DetailChip: View {
  let text: Text
  let systemImage: String?

  init(_ label: String, systemImage: String? = nil) {
    self.text = Text(label)
    self.systemImage = systemImage
  }

  init(_ labelKey: LocalizedStringKey, systemImage: String? = nil) {
    self.text = Text(labelKey)
    self.systemImage = systemImage
  }

  var body: some View {
    HStack(spacing: 4) {
      if let systemImage = systemImage {
        Image(systemName: systemImage)
          .font(.caption2)
          .foregroundStyle(.secondary)
      }
      text
        .font(.caption)
        .lineLimit(1)
    }
    .padding(.horizontal, 8)
    .padding(.vertical, 4)
    .background {
      RoundedRectangle(cornerRadius: 6, style: .continuous)
        .strokeBorder(Color.secondary.opacity(0.35), lineWidth: 1)
    }
    // The fill is transparent, so without an explicit content shape only
    // the text and border would register taps.
    .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
  }
}
