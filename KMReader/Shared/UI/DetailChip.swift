//
// DetailChip.swift
//
//

import SwiftUI

/// Filled capsule chip for detail-page metadata: one quiet neutral style,
/// no per-field colors.
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
    let content = HStack(spacing: 4) {
      if let systemImage = systemImage {
        Image(systemName: systemImage)
          .font(.caption2)
          .foregroundStyle(.secondary)
      }
      text
        .font(.caption)
        .lineLimit(1)
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 5)

    if #available(iOS 26.0, macOS 26.0, tvOS 26.0, *) {
      content
        .glassEffect(in: Capsule())
        .contentShape(Capsule())
    } else {
      content
        .background(Color.secondary.opacity(0.12), in: Capsule())
        .contentShape(Capsule())
    }
  }
}
