//
// LayoutConfig.swift
//
//

import Foundation
import SwiftUI

#if os(iOS)
  import UIKit
#endif

/// Layout configuration helper for platform-specific card sizes.
/// Card sizes are fixed per platform (calibrated against Apple Books);
/// there is no user-adjustable density.
struct LayoutConfig {

  /// Card width for browse grids (library/series/books/read lists/collections).
  static var gridCardWidth: CGFloat {
    #if os(tvOS)
      return 240
    #elseif os(macOS)
      return 224
    #else
      if UIDevice.current.userInterfaceIdiom == .pad {
        return 192
      } else {
        return 160
      }
    #endif
  }

  /// Large dashboard card width (showcase sections, e.g. recently added books).
  static var dashboardLargeCardWidth: CGFloat {
    #if os(tvOS)
      return 365
    #elseif os(macOS)
      return 213
    #else
      if UIDevice.current.userInterfaceIdiom == .pad {
        return 182
      } else {
        return 152
      }
    #endif
  }

  /// Small dashboard card width (utility sections, e.g. on deck, series).
  static var dashboardSmallCardWidth: CGFloat {
    #if os(tvOS)
      return 173
    #elseif os(macOS)
      return 101
    #else
      if UIDevice.current.userInterfaceIdiom == .pad {
        return 86
      } else {
        return 72
      }
    #endif
  }

  /// Width of horizontal cards (dashboard book sections, pinned read lists/collections).
  static var horizontalCardWidth: CGFloat {
    #if os(tvOS)
      return 528
    #elseif os(macOS)
      return 308
    #else
      if UIDevice.current.userInterfaceIdiom == .pad {
        return 264
      } else {
        return 220
      }
    #endif
  }

  /// Cover width inside horizontal cards
  static var horizontalCoverWidth: CGFloat {
    let cardWidth = horizontalCardWidth
    // The cover must stay taller than the text column (series + two-line
    // title + bottom bar ≈ 70pt on iPhone) so the cover, not the text,
    // drives the card height.
    #if os(tvOS)
      return min(max(cardWidth * 0.23, 56), 140)
    #else
      return min(max(cardWidth * 0.23, 32), 96)
    #endif
  }

  /// Title text style below large dashboard card covers (book/series title).
  static var largeCardTitleTextStyle: Font.TextStyle {
    #if os(tvOS)
      return .callout
    #elseif os(macOS)
      return .body
    #else
      if UIDevice.current.userInterfaceIdiom == .pad {
        return .body
      } else {
        return .callout
      }
    #endif
  }

  /// Secondary text style below large dashboard card covers (series, progress, metadata).
  static var largeCardSecondaryTextStyle: Font.TextStyle {
    #if os(tvOS)
      return .footnote
    #elseif os(macOS)
      return .callout
    #else
      if UIDevice.current.userInterfaceIdiom == .pad {
        return .subheadline
      } else {
        return .footnote
      }
    #endif
  }

  /// Tertiary text style for small icons below large dashboard card covers.
  static var largeCardTertiaryTextStyle: Font.TextStyle {
    #if os(tvOS)
      return .caption
    #elseif os(macOS)
      return .footnote
    #else
      if UIDevice.current.userInterfaceIdiom == .pad {
        return .footnote
      } else {
        return .caption
      }
    #endif
  }

  /// Title text style inside horizontal cards (book title, read list/collection name).
  static var horizontalCardTitleTextStyle: Font.TextStyle {
    #if os(tvOS)
      return .callout
    #elseif os(macOS)
      return .body
    #else
      if UIDevice.current.userInterfaceIdiom == .pad {
        return .callout
      } else {
        return .footnote
      }
    #endif
  }

  /// Secondary text style inside horizontal cards (series, progress, metadata).
  static var horizontalCardSecondaryTextStyle: Font.TextStyle {
    #if os(tvOS)
      return .footnote
    #elseif os(macOS)
      return .callout
    #else
      if UIDevice.current.userInterfaceIdiom == .pad {
        return .footnote
      } else {
        return .caption
      }
    #endif
  }

  /// Tertiary text style for small icons in horizontal card accessory rows.
  static var horizontalCardTertiaryTextStyle: Font.TextStyle {
    #if os(tvOS)
      return .caption
    #elseif os(macOS)
      return .footnote
    #else
      if UIDevice.current.userInterfaceIdiom == .pad {
        return .caption
      } else {
        return .caption2
      }
    #endif
  }

  /// Corner badge (unread count/indicator) size on card covers. Scales with
  /// the card width so wide cards get a larger badge, but never drops below
  /// the badge's own base size.
  static func cardBadgeSize(cardWidth: CGFloat) -> CGFloat {
    max(UnreadCountBadge.defaultSize, (cardWidth * 0.1).rounded())
  }

  /// Default spacing between cards
  static var defaultSpacing: CGFloat {
    #if os(tvOS)
      return 40
    #elseif os(macOS)
      return 24
    #else
      return 16
    #endif
  }

  /// Adaptive grid columns based on the fixed grid card width
  static var adaptiveColumns: [GridItem] {
    [GridItem(.adaptive(minimum: gridCardWidth, maximum: .infinity), spacing: defaultSpacing)]
  }
}
