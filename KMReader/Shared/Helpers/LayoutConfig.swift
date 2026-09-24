//
// LayoutConfig.swift
//
//

import Foundation
import SwiftUI

#if os(iOS)
  import UIKit
#endif

/// Layout configuration helper for platform-specific card sizes
struct LayoutConfig {

  /// Get base card width for current platform
  static var baseCardWidth: CGFloat {
    #if os(tvOS)
      return 240
    #elseif os(macOS)
      return 140
    #else
      if UIDevice.current.userInterfaceIdiom == .pad {
        return 120
      } else {
        return 100
      }
    #endif
  }

  /// Calculate card width based on density multiplier
  static func cardWidth(for density: Double) -> CGFloat {
    baseCardWidth * CGFloat(density)
  }

  /// Width of horizontal cards (dashboard book sections, pinned read lists/collections).
  /// Horizontal cards do not follow grid density: they carry only a few short
  /// text lines, so density-scaled sizing outruns the content and looks empty.
  static var horizontalCardWidth: CGFloat {
    let proposed = baseCardWidth * 2.2
    // Fixed floors stay below the smallest compact-density proposal (176pt on
    // iPhone) so every density renders at its natural proportional width.
    #if os(tvOS)
      return min(max(proposed, 360), 660)
    #else
      return min(max(proposed, 160), 480)
    #endif
  }

  /// Cover width inside horizontal cards
  static var horizontalCoverWidth: CGFloat {
    let cardWidth = horizontalCardWidth
    // The ratio keeps the cover taller than the text column (series + two-line
    // title + bottom bar), so the cover always drives the card height.
    #if os(tvOS)
      return min(max(cardWidth * 0.25, 56), 140)
    #else
      return min(max(cardWidth * 0.25, 32), 96)
    #endif
  }

  /// Title text style inside horizontal cards (book title, read list/collection name).
  static var horizontalCardTitleTextStyle: Font.TextStyle { .subheadline }

  /// Secondary text style inside horizontal cards (series, progress, metadata).
  static var horizontalCardSecondaryTextStyle: Font.TextStyle { .footnote }

  /// Tertiary text style for small icons in horizontal card accessory rows.
  static var horizontalCardTertiaryTextStyle: Font.TextStyle { .caption }

  /// Default spacing between cards
  static var defaultSpacing: CGFloat {
    #if os(tvOS)
      return 40
    #elseif os(macOS)
      return 24
    #else
      if UIDevice.current.userInterfaceIdiom == .pad {
        return 16
      } else {
        return 12
      }
    #endif
  }

  /// Calculate spacing based on density multiplier
  static func spacing(for density: Double) -> CGFloat {
    defaultSpacing * CGFloat(density)
  }

  /// Generate adaptive grid columns based on density
  static func adaptiveColumns(for density: Double) -> [GridItem] {
    let minWidth = cardWidth(for: density)
    let spacing = spacing(for: density)
    return [GridItem(.adaptive(minimum: minWidth, maximum: .infinity), spacing: spacing)]
  }
}
