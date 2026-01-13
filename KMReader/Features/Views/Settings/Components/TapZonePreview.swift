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
    ZStack {
      Rectangle()
        .fill(Color.gray.opacity(0.1))

      switch direction {
      case .ltr:
        ComicTapZoneOverlayContent(tapZoneSize: size)
      case .rtl:
        MangaTapZoneOverlayContent(tapZoneSize: size)
      case .vertical:
        VerticalTapZoneOverlayContent(tapZoneSize: size)
      case .webtoon:
        WebtoonTapZoneOverlayContent(tapZoneSize: size)
      }
    }
  }
}
