//
//  ShadowStyle.swift
//  KMReader
//

import SwiftUI

/// Shadow style options for ThumbnailImage
enum ShadowStyle {
  /// No shadow
  case none
  /// Basic drop shadow (default for detail views)
  case basic
  /// Platform-style shadow that follows actual image bounds (for card views)
  case platform
}
