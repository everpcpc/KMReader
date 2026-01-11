//
//  LiveTextManager.swift
//  KMReader
//

import Foundation

#if !os(tvOS)
  import VisionKit
#endif

@MainActor
class LiveTextManager {
  static let shared = LiveTextManager()

  #if !os(tvOS)
    let analyzer = ImageAnalyzer()
  #endif

  private init() {}
}
