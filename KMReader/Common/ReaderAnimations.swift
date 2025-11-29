//
//  ReaderAnimations.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

/// Centralized animations used inside the reader views.
enum ReaderAnimations {
  /// Animation for page turns. Disable on tvOS to keep navigation snappy.
  static var pageTurn: Animation? {
    #if os(tvOS)
      return nil
    #else
      return .easeInOut(duration: 0.2)
    #endif
  }
}
