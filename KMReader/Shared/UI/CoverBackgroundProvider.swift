//
// CoverBackgroundProvider.swift
//
//

import CoreGraphics
import Foundation
import SwiftUI

/// Provides a heavily downscaled copy of a cached cover thumbnail, intended to
/// be rendered scaled-to-fill with a strong blur as a textured card background
/// (Apple Books style). Covers are always opaque JPEGs, so the image fully
/// covers the card without needing a base color.
actor CoverBackgroundProvider {
  static let shared = CoverBackgroundProvider()

  private var cache: [String: PlatformImage?] = [:]

  private init() {}

  func backgroundImage(instanceId: String, id: String, type: ThumbnailType) async -> PlatformImage? {
    let key = "\(instanceId)#\(type.rawValue)#\(id)"
    if let cached = cache[key] { return cached }
    let image = await load(id: id, type: type)
    cache[key] = image
    return image
  }

  func invalidate(instanceId: String, id: String, type: ThumbnailType) {
    cache["\(instanceId)#\(type.rawValue)#\(id)"] = nil
  }

  private func load(id: String, type: ThumbnailType) async -> PlatformImage? {
    guard let url = try? await ThumbnailCache.shared.ensureThumbnail(id: id, type: type),
      let data = try? Data(contentsOf: url),
      let source = CGImageSourceCreateWithData(data as CFData, nil)
    else { return nil }
    let options: [CFString: Any] = [
      kCGImageSourceThumbnailMaxPixelSize: 96,
      kCGImageSourceCreateThumbnailFromImageAlways: true,
      kCGImageSourceCreateThumbnailWithTransform: true,
    ]
    guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    else { return nil }
    #if os(iOS) || os(tvOS)
      return UIImage(cgImage: thumbnail)
    #else
      return NSImage(
        cgImage: thumbnail,
        size: NSSize(width: thumbnail.width, height: thumbnail.height)
      )
    #endif
  }
}
