//
//  LiveTextManager.swift
//  KMReader
//

import Foundation
import VisionKit

@MainActor
class LiveTextManager {
  static let shared = LiveTextManager()

  #if !os(tvOS)
    let analyzer = ImageAnalyzer()
  #endif

  private init() {}
}
