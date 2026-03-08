import CoreGraphics
import Foundation
import ImageIO
import SDWebImage
import SDWebImageWebPCoder

enum AnimatedImageSupport {
  nonisolated private static let configureCodersOnce: Void = {
    SDImageCodersManager.shared.addCoder(SDImageWebPCoder.shared)
  }()

  nonisolated static func configureCoders() {
    _ = configureCodersOnce
  }

  nonisolated static func isAnimatedImageFile(at fileURL: URL) -> Bool {
    let options = [kCGImageSourceShouldCache: false] as CFDictionary
    guard let source = CGImageSourceCreateWithURL(fileURL as CFURL, options) else {
      return false
    }
    return CGImageSourceGetCount(source) > 1
  }

  nonisolated static func posterImage(from fileURL: URL) -> PlatformImage? {
    configureCoders()

    guard let imageData = loadImageData(fileURL: fileURL) else {
      return nil
    }

    // Keep the preloaded poster as a static image so the page cache does not retain
    // the full animated payload before playback actually starts.
    return PlatformImage.sd_image(with: imageData, scale: 1, firstFrameOnly: true)
  }

  nonisolated static func loadAnimatedImage(fileURL: URL, maxPixelSize: Int?) -> SDAnimatedImage? {
    configureCoders()

    guard let imageData = loadImageData(fileURL: fileURL) else {
      return nil
    }

    if let options = coderOptions(maxPixelSize: maxPixelSize) {
      return SDAnimatedImage(data: imageData, scale: 1, options: options)
    }

    return SDAnimatedImage(data: imageData, scale: 1)
  }

  nonisolated private static func loadImageData(fileURL: URL) -> Data? {
    try? Data(contentsOf: fileURL, options: [.mappedIfSafe])
  }

  nonisolated private static func coderOptions(maxPixelSize: Int?) -> [SDImageCoderOption: Any]? {
    guard let maxPixelSize, maxPixelSize > 0 else {
      return nil
    }

    return [
      .decodeThumbnailPixelSize: CGSize(width: maxPixelSize, height: maxPixelSize)
    ]
  }
}
