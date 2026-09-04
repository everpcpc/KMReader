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

  /// Width of horizontal cards (dashboard book sections, pinned read lists/collections)
  static func horizontalCardWidth(for density: Double) -> CGFloat {
    let proposed = cardWidth(for: density) * 2.2
    // Fixed floors stay below the smallest compact-density proposal (176pt on
    // iPhone) so every density renders at its natural proportional width.
    #if os(tvOS)
      return min(max(proposed, 360), 660)
    #else
      return min(max(proposed, 160), 480)
    #endif
  }

  /// Cover width inside horizontal cards
  static func horizontalCoverWidth(for density: Double) -> CGFloat {
    let cardWidth = horizontalCardWidth(for: density)
    // Fixed floor stays below the smallest compact-density proposal (44pt on
    // iPhone) so covers keep shrinking with the card. The ratio keeps the
    // cover taller than the text column (series + two-line title + bottom
    // bar) at every density, so the cover always drives the card height.
    #if os(tvOS)
      return min(max(cardWidth * 0.25, 56), 140)
    #else
      return min(max(cardWidth * 0.25, 32), 96)
    #endif
  }

  /// Title text style inside horizontal cards (book title, read list/collection name).
  /// Cozy density steps text up one tier so the wider card doesn't look sparse.
  static func horizontalCardTitleTextStyle(for density: Double) -> Font.TextStyle {
    density > GridDensity.standard.rawValue ? .subheadline : .footnote
  }

  /// Secondary text style inside horizontal cards (series, progress, metadata).
  static func horizontalCardSecondaryTextStyle(for density: Double) -> Font.TextStyle {
    density > GridDensity.standard.rawValue ? .footnote : .caption
  }

  /// Tertiary text style for small icons in horizontal card accessory rows.
  static func horizontalCardTertiaryTextStyle(for density: Double) -> Font.TextStyle {
    density > GridDensity.standard.rawValue ? .caption : .caption2
  }

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
