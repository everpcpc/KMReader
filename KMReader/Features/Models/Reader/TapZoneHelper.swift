//
//  TapZoneHelper.swift
//  KMReader
//
//  Created by Antigravity
//

import Foundation

/// Result of tap zone detection
enum TapZoneAction {
  case previous
  case next
  case toggleControls
}

/// Centralized helper to determine tap zone actions based on TapZoneMode and tap location
enum TapZoneHelper {
  /// Determine the action for a tap at the given normalized location
  /// - Parameters:
  ///   - normalizedX: X position normalized to 0...1 (0 = left, 1 = right)
  ///   - normalizedY: Y position normalized to 0...1 (0 = top, 1 = bottom)
  ///   - tapZoneMode: The tap zone mode setting
  ///   - readingDirection: The current reading direction (used when mode is .auto)
  ///   - zoneThreshold: The tap zone threshold (from TapZoneSize.value)
  /// - Returns: The action to perform
  static func action(
    normalizedX: CGFloat,
    normalizedY: CGFloat,
    tapZoneMode: TapZoneMode,
    readingDirection: ReadingDirection,
    zoneThreshold: CGFloat
  ) -> TapZoneAction {
    // Handle none mode - always toggle controls
    guard let effectiveDirection = tapZoneMode.effectiveDirection(for: readingDirection) else {
      return .toggleControls
    }

    return actionForDirection(
      normalizedX: normalizedX,
      normalizedY: normalizedY,
      direction: effectiveDirection,
      zoneThreshold: zoneThreshold
    )
  }

  /// Determine the action for a tap based on a specific direction
  private static func actionForDirection(
    normalizedX: CGFloat,
    normalizedY: CGFloat,
    direction: ReadingDirection,
    zoneThreshold: CGFloat
  ) -> TapZoneAction {
    switch direction {
    case .ltr:
      // Left-to-right: left=previous, right=next, center=controls
      if normalizedX < zoneThreshold {
        return .previous
      } else if normalizedX > (1.0 - zoneThreshold) {
        return .next
      } else {
        return .toggleControls
      }

    case .rtl:
      // Right-to-left: right=previous, left=next, center=controls
      if normalizedX > (1.0 - zoneThreshold) {
        return .previous
      } else if normalizedX < zoneThreshold {
        return .next
      } else {
        return .toggleControls
      }

    case .vertical:
      // Vertical: top=previous, bottom=next, center=controls
      if normalizedY < zoneThreshold {
        return .previous
      } else if normalizedY > (1.0 - zoneThreshold) {
        return .next
      } else {
        return .toggleControls
      }

    case .webtoon:
      // L-shaped zones: top + left = previous, bottom + right = next
      let isTopArea = normalizedY < zoneThreshold
      let isBottomArea = normalizedY > (1.0 - zoneThreshold)
      let isMiddleY = !isTopArea && !isBottomArea
      let isLeftArea = normalizedX < zoneThreshold

      let isCenterArea =
        normalizedX > zoneThreshold
        && normalizedX < (1.0 - zoneThreshold)
        && normalizedY > zoneThreshold
        && normalizedY < (1.0 - zoneThreshold)

      if isCenterArea {
        return .toggleControls
      } else if isTopArea || (isMiddleY && isLeftArea) {
        return .previous
      } else {
        return .next
      }
    }
  }
}
