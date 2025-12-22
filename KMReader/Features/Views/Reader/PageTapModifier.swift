//
//  PageTapModifier.swift
//  KMReader
//
//  Created by antigravity on 2025/12/15.
//

import SwiftUI

struct PageTapModifier: ViewModifier {
  let size: CGSize
  let readingDirection: ReadingDirection
  let onNextPage: () -> Void
  let onPreviousPage: () -> Void
  let onToggleControls: () -> Void

  @AppStorage("disableTapToTurnPage") private var disableTapToTurnPage: Bool = false

  func body(content: Content) -> some View {
    #if os(iOS) || os(macOS)
      content
        .contentShape(Rectangle())
        .simultaneousGesture(
          SpatialTapGesture()
            .onEnded { value in
              handleTap(at: value.location)
            }
        )
    #else
      content
    #endif
  }

  private func handleTap(at location: CGPoint) {
    if readingDirection == .vertical || readingDirection == .webtoon {
      handleVerticalTap(at: location)
    } else {
      handleHorizontalTap(at: location)
    }
  }

  private func handleHorizontalTap(at location: CGPoint) {
    guard size.width > 0 else { return }
    let normalizedX = max(0, min(1, location.x / size.width))

    if normalizedX < 0.3 {
      // Left tap
      if !disableTapToTurnPage {
        if readingDirection == .rtl {
          onNextPage()
        } else {
          onPreviousPage()
        }
      }
    } else if normalizedX > 0.7 {
      // Right tap
      if !disableTapToTurnPage {
        if readingDirection == .rtl {
          onPreviousPage()
        } else {
          onNextPage()
        }
      }
    } else {
      onToggleControls()
    }
  }

  private func handleVerticalTap(at location: CGPoint) {
    guard size.height > 0 else { return }
    let normalizedY = max(0, min(1, location.y / size.height))

    if normalizedY < 0.3 {
      // Top tap
      if !disableTapToTurnPage {
        onPreviousPage()
      }
    } else if normalizedY > 0.7 {
      // Bottom tap
      if !disableTapToTurnPage {
        onNextPage()
      }
    } else {
      onToggleControls()
    }
  }
}

extension View {
  func pageTapGesture(
    size: CGSize,
    readingDirection: ReadingDirection,
    onNextPage: @escaping () -> Void,
    onPreviousPage: @escaping () -> Void,
    onToggleControls: @escaping () -> Void
  ) -> some View {
    modifier(
      PageTapModifier(
        size: size,
        readingDirection: readingDirection,
        onNextPage: onNextPage,
        onPreviousPage: onPreviousPage,
        onToggleControls: onToggleControls
      )
    )
  }
}
