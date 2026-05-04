//
// TapZonePreview.swift
//
//

import SwiftUI

struct TapZonePreview: View {
  let tapZoneMode: TapZoneMode
  let tapZoneInversionMode: TapZoneInversionMode
  let readingDirection: ReadingDirection
  let previewAspectRatio: CGFloat
  let caption: String?

  init(
    tapZoneMode: TapZoneMode,
    tapZoneInversionMode: TapZoneInversionMode,
    readingDirection: ReadingDirection,
    previewAspectRatio: CGFloat,
    caption: String? = nil
  ) {
    self.tapZoneMode = tapZoneMode
    self.tapZoneInversionMode = tapZoneInversionMode
    self.readingDirection = readingDirection
    self.previewAspectRatio = previewAspectRatio
    self.caption = caption
  }

  var body: some View {
    VStack(spacing: 4) {
      previewContent
        .aspectRatio(previewAspectRatio, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(
          RoundedRectangle(cornerRadius: 4)
            .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
        )

      Text(caption ?? readingDirection.displayName)
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

      TapZoneGridOverlayContent(
        tapZoneMode: tapZoneMode,
        tapZoneInversionMode: tapZoneInversionMode,
        readingDirection: readingDirection
      )
    }
  }
}
