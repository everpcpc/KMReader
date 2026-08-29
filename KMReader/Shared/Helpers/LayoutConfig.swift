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
    #if os(tvOS)
      return min(max(proposed, 360), 660)
    #else
      return min(max(proposed, 240), 480)
    #endif
  }

  /// Cover width inside horizontal cards
  static func horizontalCoverWidth(for density: Double) -> CGFloat {
    let cardWidth = horizontalCardWidth(for: density)
    #if os(tvOS)
      return min(max(cardWidth * 0.21, 56), 140)
    #else
      return min(max(cardWidth * 0.21, 48), 96)
    #endif
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
