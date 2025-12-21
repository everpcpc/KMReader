//
//  InfoChip.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct InfoChip: View {
  private let label: Text
  let systemImage: String?
  let backgroundColor: Color
  let foregroundColor: Color
  let cornerRadius: CGFloat

  init(
    labelKey: LocalizedStringKey,
    systemImage: String? = nil,
    backgroundColor: Color = Color.secondary.opacity(0.2),
    foregroundColor: Color = .primary,
    cornerRadius: CGFloat = 16
  ) {
    self.label = Text(labelKey)
    self.systemImage = systemImage
    self.backgroundColor = backgroundColor
    self.foregroundColor = foregroundColor
    self.cornerRadius = cornerRadius
  }

  init(
    label: String,
    systemImage: String? = nil,
    backgroundColor: Color = Color.secondary.opacity(0.2),
    foregroundColor: Color = .primary,
    cornerRadius: CGFloat = 16
  ) {
    self.label = Text(label)
    self.systemImage = systemImage
    self.backgroundColor = backgroundColor
    self.foregroundColor = foregroundColor
    self.cornerRadius = cornerRadius
  }

  var body: some View {
    HStack(spacing: 4) {
      if let systemImage = systemImage {
        Image(systemName: systemImage)
          .font(.caption2)
      }
      label
        .font(.caption)
        .lineLimit(1)
        .textSelectionIfAvailable()
    }
    .foregroundColor(foregroundColor)
    .padding(.horizontal, 8)
    .padding(.vertical, 4)
    .background(backgroundColor)
    .cornerRadius(cornerRadius)
  }
}
