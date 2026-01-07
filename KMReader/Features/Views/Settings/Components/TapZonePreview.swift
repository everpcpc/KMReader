//
//  TapZonePreview.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct TapZonePreview: View {
  let size: TapZoneSize
  let direction: ReadingDirection

  private var zoneValue: CGFloat { size.value }

  private var aspectRatio: CGFloat {
    switch direction {
    case .vertical, .webtoon:
      return 0.707
    case .ltr, .rtl:
      return 1.414
    }
  }

  var body: some View {
    VStack(spacing: 4) {
      previewContent
        .aspectRatio(aspectRatio, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(
          RoundedRectangle(cornerRadius: 4)
            .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
        )

      Text(direction.displayName)
        .font(.caption2)
        .foregroundColor(.secondary)
        .lineLimit(1)
    }
  }

  @ViewBuilder
  private var previewContent: some View {
    switch direction {
    case .ltr:
      horizontalPreview(isRTL: false)
    case .rtl:
      horizontalPreview(isRTL: true)
    case .vertical:
      verticalPreview
    case .webtoon:
      webtoonPreview
    }
  }

  private func horizontalPreview(isRTL: Bool) -> some View {
    GeometryReader { geometry in
      HStack(spacing: 0) {
        Rectangle()
          .fill(isRTL ? Color.green.opacity(0.5) : Color.red.opacity(0.5))
          .frame(width: geometry.size.width * zoneValue)

        Rectangle()
          .fill(Color.gray.opacity(0.2))

        Rectangle()
          .fill(isRTL ? Color.red.opacity(0.5) : Color.green.opacity(0.5))
          .frame(width: geometry.size.width * zoneValue)
      }
    }
  }

  private var verticalPreview: some View {
    GeometryReader { geometry in
      VStack(spacing: 0) {
        Rectangle()
          .fill(Color.red.opacity(0.5))
          .frame(height: geometry.size.height * zoneValue)

        Rectangle()
          .fill(Color.gray.opacity(0.2))

        Rectangle()
          .fill(Color.green.opacity(0.5))
          .frame(height: geometry.size.height * zoneValue)
      }
    }
  }

  private var webtoonPreview: some View {
    GeometryReader { geometry in
      let w = geometry.size.width
      let h = geometry.size.height

      ZStack(alignment: .topLeading) {
        // Center area (gray)
        Rectangle()
          .fill(Color.gray.opacity(0.2))

        // Top area (red) - full width
        Rectangle()
          .fill(Color.red.opacity(0.5))
          .frame(width: w, height: h * zoneValue)

        // Left middle area (red)
        Rectangle()
          .fill(Color.red.opacity(0.5))
          .frame(width: w * zoneValue, height: h * (1.0 - 2 * zoneValue))
          .offset(y: h * zoneValue)

        // Right middle area (green)
        Rectangle()
          .fill(Color.green.opacity(0.5))
          .frame(width: w * zoneValue, height: h * (1.0 - 2 * zoneValue))
          .offset(x: w * (1.0 - zoneValue), y: h * zoneValue)

        // Bottom area (green) - full width
        Rectangle()
          .fill(Color.green.opacity(0.5))
          .frame(width: w, height: h * zoneValue)
          .offset(y: h * (1.0 - zoneValue))
      }
    }
  }
}
