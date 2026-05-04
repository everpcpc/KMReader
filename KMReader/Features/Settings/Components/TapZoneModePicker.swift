//
// TapZoneModePicker.swift
//
//

import SwiftUI

#if os(iOS) || os(tvOS)
  import UIKit
#elseif os(macOS)
  import AppKit
#endif

struct TapZoneModePicker: View {
  @Binding var selection: TapZoneMode
  let tapZoneInversionMode: TapZoneInversionMode
  let readingDirection: ReadingDirection

  private var columns: [GridItem] {
    Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)
  }

  private var previewAspectRatio: CGFloat {
    isPortraitScreen ? CoverAspectRatio.widthToHeight : CoverAspectRatio.heightToWidth
  }

  var body: some View {
    LazyVGrid(columns: columns, spacing: 12) {
      ForEach(TapZoneMode.allCases, id: \.self) { mode in
        modeButton(for: mode)
      }
    }
    .padding(.vertical, 4)
  }

  private func modeButton(for mode: TapZoneMode) -> some View {
    let isSelected = selection == mode

    return Button {
      selection = mode
    } label: {
      TapZonePreview(
        tapZoneMode: mode,
        tapZoneInversionMode: tapZoneInversionMode,
        readingDirection: readingDirection,
        previewAspectRatio: previewAspectRatio,
        caption: mode.displayName
      )
      .frame(maxWidth: .infinity)
      .padding(8)
      .background(Color.secondary.opacity(0.08))
      .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: 12, style: .continuous)
          .stroke(isSelected ? Color.accentColor : Color.secondary.opacity(0.2), lineWidth: isSelected ? 2 : 1)
      )
    }
    .buttonStyle(.plain)
    .accessibilityAddTraits(isSelected ? .isSelected : [])
  }

  private var isPortraitScreen: Bool {
    #if os(iOS) || os(tvOS)
      let size = UIScreen.main.bounds.size
    #elseif os(macOS)
      let size = NSScreen.main?.visibleFrame.size ?? CGSize(width: 16, height: 10)
    #else
      let size = CGSize(width: 16, height: 10)
    #endif

    return size.width < size.height
  }
}
