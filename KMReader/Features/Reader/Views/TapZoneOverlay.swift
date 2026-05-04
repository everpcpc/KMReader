//
// TapZoneOverlay.swift
//
//

import SwiftUI

struct TapZoneOverlay: View {
  @Binding var isVisible: Bool
  let readingDirection: ReadingDirection

  @AppStorage("showTapZoneHints") private var showTapZoneHints: Bool = true
  @AppStorage("tapZoneMode") private var tapZoneMode: TapZoneMode = .defaultLayout
  @AppStorage("tapZoneInversionMode") private var tapZoneInversionMode: TapZoneInversionMode = .auto

  var body: some View {
    TapZoneGridOverlayContent(
      tapZoneMode: tapZoneMode,
      tapZoneInversionMode: tapZoneInversionMode,
      readingDirection: readingDirection
    )
    .opacity(isVisible && showTapZoneHints && !tapZoneMode.isDisabled ? 1.0 : 0.0)
    .allowsHitTesting(false)
    .onAppear {
      guard showTapZoneHints && !tapZoneMode.isDisabled else { return }
      isVisible = true
    }
  }
}

struct TapZoneGridOverlayContent: View {
  let tapZoneMode: TapZoneMode
  let tapZoneInversionMode: TapZoneInversionMode
  let readingDirection: ReadingDirection

  var body: some View {
    GeometryReader { geometry in
      VStack(spacing: 0) {
        ForEach(0..<3, id: \.self) { row in
          HStack(spacing: 0) {
            ForEach(0..<3, id: \.self) { column in
              Rectangle()
                .fill(color(row: row, column: column).opacity(0.3))
                .frame(width: geometry.size.width / 3, height: geometry.size.height / 3)
            }
          }
        }
      }
    }
  }

  private func color(row: Int, column: Int) -> Color {
    switch TapZoneHelper.action(
      row: row,
      column: column,
      tapZoneMode: tapZoneMode,
      tapZoneInversionMode: tapZoneInversionMode,
      readingDirection: readingDirection
    ) {
    case .previous:
      return .red
    case .next:
      return .green
    case .toggleControls:
      return .blue
    }
  }
}
