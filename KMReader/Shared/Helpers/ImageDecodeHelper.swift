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
  nonisolated static func decodeForDisplay(_ image: PlatformImage) -> PlatformImage {
    #if os(iOS) || os(tvOS)
      return image.preparingForDisplay() ?? image
    #elseif os(macOS)
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
