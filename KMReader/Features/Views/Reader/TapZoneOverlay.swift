//
//  TapZoneOverlay.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

// Overlay for Comic page view (LTR horizontal)
struct ComicTapZoneOverlay: View {
  @AppStorage("showTapZoneHints") private var showTapZoneHints: Bool = true
  @AppStorage("disableTapToTurnPage") private var disableTapToTurnPage: Bool = false
  @AppStorage("tapZoneSize") private var tapZoneSize: TapZoneSize = .large
  @Binding var isVisible: Bool

  var body: some View {
    GeometryReader { geometry in
      HStack(spacing: 0) {
        // Left zone - Previous page
        Rectangle()
          .fill(Color.red.opacity(0.3))
          .frame(width: geometry.size.width * tapZoneSize.value)

        Spacer()

        // Right zone - Next page
        Rectangle()
          .fill(Color.green.opacity(0.3))
          .frame(width: geometry.size.width * tapZoneSize.value)
      }
      .opacity(isVisible && showTapZoneHints && !disableTapToTurnPage ? 1.0 : 0.0)
      .allowsHitTesting(false)
      .onAppear {
        guard showTapZoneHints && !disableTapToTurnPage else { return }
        // Show overlay immediately
        isVisible = true
      }
    }
  }
}

// Overlay for Manga page view (RTL horizontal)
struct MangaTapZoneOverlay: View {
  @AppStorage("showTapZoneHints") private var showTapZoneHints: Bool = true
  @AppStorage("disableTapToTurnPage") private var disableTapToTurnPage: Bool = false
  @AppStorage("tapZoneSize") private var tapZoneSize: TapZoneSize = .large
  @Binding var isVisible: Bool

  var body: some View {
    GeometryReader { geometry in
      HStack(spacing: 0) {
        // Left zone - Next page
        Rectangle()
          .fill(Color.green.opacity(0.3))
          .frame(width: geometry.size.width * tapZoneSize.value)

        Spacer()

        // Right zone - Previous page
        Rectangle()
          .fill(Color.red.opacity(0.3))
          .frame(width: geometry.size.width * tapZoneSize.value)
      }
      .opacity(isVisible && showTapZoneHints && !disableTapToTurnPage ? 1.0 : 0.0)
      .allowsHitTesting(false)
      .onAppear {
        guard showTapZoneHints && !disableTapToTurnPage else { return }
        // Show overlay immediately
        isVisible = true
      }
    }
  }
}

// Overlay for Vertical page view
struct VerticalTapZoneOverlay: View {
  @AppStorage("showTapZoneHints") private var showTapZoneHints: Bool = true
  @AppStorage("disableTapToTurnPage") private var disableTapToTurnPage: Bool = false
  @AppStorage("tapZoneSize") private var tapZoneSize: TapZoneSize = .large
  @Binding var isVisible: Bool

  var body: some View {
    GeometryReader { geometry in
      VStack(spacing: 0) {
        // Previous page zone (top)
        Rectangle()
          .fill(Color.red.opacity(0.3))
          .frame(height: geometry.size.height * tapZoneSize.value)

        Spacer()

        // Next page zone (bottom)
        Rectangle()
          .fill(Color.green.opacity(0.3))
          .frame(height: geometry.size.height * tapZoneSize.value)
      }
      .opacity(isVisible && showTapZoneHints && !disableTapToTurnPage ? 1.0 : 0.0)
      .allowsHitTesting(false)
      .onAppear {
        guard showTapZoneHints && !disableTapToTurnPage else { return }
        // Show overlay immediately
        isVisible = true
      }
    }
  }
}

// Overlay for webtoon view - L-shaped tap zones
#if os(iOS) || os(macOS)
  struct WebtoonTapZoneOverlay: View {
    @AppStorage("showTapZoneHints") private var showTapZoneHints: Bool = true
    @AppStorage("disableTapToTurnPage") private var disableTapToTurnPage: Bool = false
    @AppStorage("tapZoneSize") private var tapZoneSize: TapZoneSize = .large
    @Binding var isVisible: Bool

    private var topAreaThreshold: CGFloat { tapZoneSize.value }
    private var bottomAreaThreshold: CGFloat { 1.0 - tapZoneSize.value }
    private var centerAreaMin: CGFloat { tapZoneSize.value }
    private var centerAreaMax: CGFloat { 1.0 - tapZoneSize.value }

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

          // Center area border (transparent to show the center toggle area)
          Rectangle()
            .fill(Color.clear)
            .frame(
              width: geometry.size.width * (centerAreaMax - centerAreaMin),
              height: geometry.size.height * (centerAreaMax - centerAreaMin)
            )
            .position(
              x: geometry.size.width * (centerAreaMin + centerAreaMax) / 2,
              y: geometry.size.height * (centerAreaMin + centerAreaMax) / 2
            )
        }
        .opacity(isVisible && showTapZoneHints && !disableTapToTurnPage ? 1.0 : 0.0)
        .allowsHitTesting(false)
        .onAppear {
          guard showTapZoneHints && !disableTapToTurnPage else { return }
          // Show overlay immediately
          isVisible = true
        }
      }
    }
  }
#endif
