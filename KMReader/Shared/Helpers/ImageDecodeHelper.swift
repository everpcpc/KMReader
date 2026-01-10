//
//  ImageDecodeHelper.swift
//  Komga
//
//  Created by Komga iOS Client
//

import CoreGraphics
import Foundation

#if os(iOS) || os(tvOS)
  import UIKit
#elseif os(macOS)
  import AppKit
#endif

struct ImageDecodeHelper {
  /// Decodes image for display asynchronously to avoid blocking the caller and priority inversion.
  /// - Note: This function should be called from a background context to avoid blocking the main thread,
  /// especially on macOS where it performs synchronous drawing.
  nonisolated static func decodeForDisplay(_ image: PlatformImage) async -> PlatformImage {
    #if os(iOS) || os(tvOS)
      // Use the modern asynchronous decoding API which handles QoS internally
      return await image.byPreparingForDisplay() ?? image
    #elseif os(macOS)
      // On macOS, we perform the decode by drawing into a new context.
      // We assume the caller is running in an async background context (e.g. Task.detached or TaskGroup).
      guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
        return image
      }
      let width = cgImage.width
      let height = cgImage.height
      guard width > 0, height > 0 else { return image }

      let colorSpace = cgImage.colorSpace ?? CGColorSpaceCreateDeviceRGB()
      let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue

      guard
        let context = CGContext(
          data: nil,
          width: width,
          height: height,
          bitsPerComponent: 8,
          bytesPerRow: 0,
          space: colorSpace,
          bitmapInfo: bitmapInfo
        )
      else {
        return image
      }

      context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
      guard let decoded = context.makeImage() else { return image }
      return NSImage(cgImage: decoded, size: image.size)
    #else
      return image
    #endif
  }
}
