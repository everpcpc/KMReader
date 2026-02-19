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
