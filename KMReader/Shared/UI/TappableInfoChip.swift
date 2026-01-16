//
//  TappableInfoChip.swift
//  KMReader
//
//  Created by Komga iOS Client
//

import SwiftUI

/// A tappable version of InfoChip that can navigate to a destination
struct TappableInfoChip: View {
  private let label: Text
  private let labelString: String
  let systemImage: String?
  let backgroundColor: Color
  let foregroundColor: Color
  let cornerRadius: CGFloat
  let destination: NavDestination

  init(
    labelKey: LocalizedStringKey,
    systemImage: String? = nil,
    backgroundColor: Color = Color.secondary.opacity(0.2),
    foregroundColor: Color = .primary,
    cornerRadius: CGFloat = 16,
    destination: NavDestination
  ) {
    let mirror = Mirror(reflecting: labelKey)
    let key = mirror.children.first(where: { $0.label == "key" })?.value as? String ?? ""

    self.label = Text(labelKey)
    self.labelString = key
    self.systemImage = systemImage
    self.backgroundColor = backgroundColor
    self.foregroundColor = foregroundColor
    self.cornerRadius = cornerRadius
    self.destination = destination
  }

  init(
    label: String,
    systemImage: String? = nil,
    backgroundColor: Color = Color.secondary.opacity(0.2),
    foregroundColor: Color = .primary,
    cornerRadius: CGFloat = 16,
    destination: NavDestination
  ) {
    self.label = Text(label)
    self.labelString = label
    self.systemImage = systemImage
    self.backgroundColor = backgroundColor
    self.foregroundColor = foregroundColor
    self.cornerRadius = cornerRadius
    self.destination = destination
  }

  var body: some View {
    NavigationLink(value: destination) {
      HStack(spacing: 4) {
        if let systemImage = systemImage {
          Image(systemName: systemImage)
            .font(.caption2)
        }
        label
          .font(.caption)
          .lineLimit(1)
      }
      .foregroundColor(foregroundColor)
      .padding(.horizontal, 8)
      .padding(.vertical, 4)
      .background(backgroundColor)
      .cornerRadius(cornerRadius)
    }
    .adaptiveButtonStyle(.plain)
    #if os(iOS) || os(macOS)
      .contextMenu {
        Button {
          PlatformHelper.generalPasteboard.string = labelString
        } label: {
          Label("Copy", systemImage: "doc.on.doc")
        }
      }
    #endif
  }
}
