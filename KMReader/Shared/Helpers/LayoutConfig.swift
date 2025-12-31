//
//  LayoutConfig.swift
//  KMReader
//
//  Created by Komga iOS Client
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
      // iOS
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
  static var spacing: CGFloat {
    #if os(tvOS)
      return 40
    #elseif os(macOS)
      return 24
    #else
      return 16
    #endif
  }

  /// Generate adaptive grid columns based on density
  static func adaptiveColumns(for density: Double) -> [GridItem] {
    let minWidth = cardWidth(for: density)
    return [GridItem(.adaptive(minimum: minWidth, maximum: .infinity), spacing: spacing)]
  }
}
