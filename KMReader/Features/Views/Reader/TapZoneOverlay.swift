//
//  TapZoneOverlay.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

/// Unified tap zone overlay that displays the correct layout based on TapZoneMode
struct TapZoneOverlay: View {
  @AppStorage("showTapZoneHints") private var showTapZoneHints: Bool = true
  @AppStorage("tapZoneMode") private var tapZoneMode: TapZoneMode = .auto
  @AppStorage("tapZoneSize") private var tapZoneSize: TapZoneSize = .large
  @Binding var isVisible: Bool
  let readingDirection: ReadingDirection

  var body: some View {
    Group {
      if let effectiveDirection = tapZoneMode.effectiveDirection(for: readingDirection) {
        switch effectiveDirection {
        case .ltr:
          ComicTapZoneOverlayContent(tapZoneSize: tapZoneSize)
        case .rtl:
          MangaTapZoneOverlayContent(tapZoneSize: tapZoneSize)
        case .vertical:
          VerticalTapZoneOverlayContent(tapZoneSize: tapZoneSize)
        case .webtoon:
          WebtoonTapZoneOverlayContent(tapZoneSize: tapZoneSize)
        }
      }
    }
    .opacity(isVisible && showTapZoneHints && !tapZoneMode.isDisabled ? 1.0 : 0.0)
    .allowsHitTesting(false)
    .onAppear {
      guard showTapZoneHints && !tapZoneMode.isDisabled else { return }
      isVisible = true
    }
  }
}

// MARK: - Overlay Content Views

struct ComicTapZoneOverlayContent: View {
  let tapZoneSize: TapZoneSize

  var body: some View {
    GeometryReader { geometry in
      HStack(spacing: 0) {
        Rectangle()
          .fill(Color.red.opacity(0.3))
          .frame(width: geometry.size.width * tapZoneSize.value)
        Spacer()
        Rectangle()
          .fill(Color.green.opacity(0.3))
          .frame(width: geometry.size.width * tapZoneSize.value)
      }
    }
  }
}

struct MangaTapZoneOverlayContent: View {
  let tapZoneSize: TapZoneSize

  var body: some View {
    GeometryReader { geometry in
      HStack(spacing: 0) {
        Rectangle()
          .fill(Color.green.opacity(0.3))
          .frame(width: geometry.size.width * tapZoneSize.value)
        Spacer()
        Rectangle()
          .fill(Color.red.opacity(0.3))
          .frame(width: geometry.size.width * tapZoneSize.value)
      }
    }
  }
}

struct VerticalTapZoneOverlayContent: View {
  let tapZoneSize: TapZoneSize

  var body: some View {
    GeometryReader { geometry in
      VStack(spacing: 0) {
        Rectangle()
          .fill(Color.red.opacity(0.3))
          .frame(height: geometry.size.height * tapZoneSize.value)
        Spacer()
        Rectangle()
          .fill(Color.green.opacity(0.3))
          .frame(height: geometry.size.height * tapZoneSize.value)
      }
    }
  }
}

struct WebtoonTapZoneOverlayContent: View {
  let tapZoneSize: TapZoneSize

  private var topAreaThreshold: CGFloat { tapZoneSize.value }
  private var centerAreaMin: CGFloat { tapZoneSize.value }
  private var centerAreaMax: CGFloat { 1.0 - tapZoneSize.value }
  private var bottomAreaThreshold: CGFloat { 1.0 - tapZoneSize.value }

  var body: some View {
    GeometryReader { geometry in
      ZStack(alignment: .topLeading) {
        // Red area - Top full width
        Rectangle()
          .fill(Color.red.opacity(0.3))
          .frame(
            width: geometry.size.width,
            height: geometry.size.height * topAreaThreshold
          )
          .position(
            x: geometry.size.width / 2,
            y: geometry.size.height * topAreaThreshold / 2
          )

        // Red area - Left middle
        Rectangle()
          .fill(Color.red.opacity(0.3))
          .frame(
            width: geometry.size.width * topAreaThreshold,
            height: geometry.size.height * (centerAreaMax - centerAreaMin)
          )
          .position(
            x: geometry.size.width * topAreaThreshold / 2,
            y: geometry.size.height * (centerAreaMin + centerAreaMax) / 2
          )

        // Green area - Right middle
        Rectangle()
          .fill(Color.green.opacity(0.3))
          .frame(
            width: geometry.size.width * (1.0 - centerAreaMax),
            height: geometry.size.height * (centerAreaMax - centerAreaMin)
          )
          .position(
            x: geometry.size.width * (centerAreaMax + 1.0) / 2,
            y: geometry.size.height * (centerAreaMin + centerAreaMax) / 2
          )

        // Green area - Bottom full width
        Rectangle()
          .fill(Color.green.opacity(0.3))
          .frame(
            width: geometry.size.width,
            height: geometry.size.height * (1.0 - bottomAreaThreshold)
          )
          .position(
            x: geometry.size.width / 2,
            y: geometry.size.height * (bottomAreaThreshold + 1.0) / 2
          )
      }
    }
  }
}
