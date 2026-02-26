//
// ReaderImageBlendHelper.swift
//
//

import Foundation

#if os(iOS) || os(tvOS)
  import UIKit

  enum ReaderImageBlendHelper {
    static func multiply(image: UIImage, tintColor: UIColor) -> UIImage? {
      let size = image.size
      guard size.width > 0, size.height > 0 else { return image }

      let format = UIGraphicsImageRendererFormat.preferred()
      format.scale = image.scale
      format.opaque = false
      let renderer = UIGraphicsImageRenderer(size: size, format: format)

      return renderer.image { context in
        let rect = CGRect(origin: .zero, size: size)
        image.draw(in: rect)
        context.cgContext.setBlendMode(.multiply)
        context.cgContext.setFillColor(tintColor.cgColor)
        context.cgContext.fill(rect)
      }
    }
  }
#elseif os(macOS)
  import AppKit

  enum ReaderImageBlendHelper {
    static func multiply(image: NSImage, tintColor: NSColor) -> NSImage? {
      guard
        let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
      else {
        return image
      }

      let width = cgImage.width
      let height = cgImage.height
      guard width > 0, height > 0 else { return image }

      let colorSpace = CGColorSpaceCreateDeviceRGB()
      guard
        let context = CGContext(
          data: nil,
          width: width,
          height: height,
          bitsPerComponent: 8,
          bytesPerRow: 0,
          space: colorSpace,
          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
      else {
        return image
      }

      let rect = CGRect(x: 0, y: 0, width: width, height: height)
      context.draw(cgImage, in: rect)
      context.setBlendMode(.multiply)
      context.setFillColor(tintColor.cgColor)
      context.fill(rect)

      guard let blendedCGImage = context.makeImage() else {
        return image
      }

      return NSImage(cgImage: blendedCGImage, size: image.size)
    }
  }
#endif
