//
// LiveTextManager.swift
//
//

import Foundation

#if os(iOS) || os(macOS)
  import VisionKit
#endif

@MainActor
class LiveTextManager {
  static let shared = LiveTextManager()

  #if os(iOS) || os(macOS)
    let analyzer = ImageAnalyzer()
  #endif

  private init() {}
}
