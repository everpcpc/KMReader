import Foundation
import ImageIO

nonisolated final class AnimatedImageFrameDecoder {
  private static let fallbackFrameDuration: Double = 0.1
  private static let minimumFrameDuration: Double = 1.0 / 30.0
  private static let lowDelayFrameThreshold: Double = 0.011

  static var frameDurationFallback: TimeInterval {
    fallbackFrameDuration
  }

  private let source: CGImageSource
  let frameCount: Int
  let frameDurations: [TimeInterval]
  let posterFrame: CGImage?

  init?(fileURL: URL) {
    let options = [kCGImageSourceShouldCache: false] as CFDictionary
    guard let source = CGImageSourceCreateWithURL(fileURL as CFURL, options) else {
      return nil
    }
    let count = CGImageSourceGetCount(source)
    guard count > 1 else {
      return nil
    }
    self.source = source
    self.frameCount = count

    var frameDurations: [TimeInterval] = []
    frameDurations.reserveCapacity(count)
    for index in 0..<count {
      frameDurations.append(Self.resolveFrameDuration(for: source, at: index))
    }
    self.frameDurations = frameDurations
    self.posterFrame = Self.decodeFrame(from: source, at: 0, maxPixelSize: nil)
  }

  func frameDuration(at index: Int) -> TimeInterval {
    guard index >= 0, index < frameCount else {
      return Self.fallbackFrameDuration
    }
    return frameDurations[index]
  }

  func decodeFrame(at index: Int, maxPixelSize: Int?) -> CGImage? {
    guard index >= 0, index < frameCount else { return nil }
    return Self.decodeFrame(from: source, at: index, maxPixelSize: maxPixelSize)
  }

  private static func resolveFrameDuration(for source: CGImageSource, at index: Int) -> TimeInterval {
    guard
      let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any]
    else {
      return Self.fallbackFrameDuration
    }

    let gifDuration = Self.parseDuration(
      dictionary: properties[kCGImagePropertyGIFDictionary] as? [CFString: Any],
      unclampedKey: kCGImagePropertyGIFUnclampedDelayTime,
      clampedKey: kCGImagePropertyGIFDelayTime
    )
    let webpDuration = Self.parseDuration(
      dictionary: properties[kCGImagePropertyWebPDictionary] as? [CFString: Any],
      unclampedKey: kCGImagePropertyWebPUnclampedDelayTime,
      clampedKey: kCGImagePropertyWebPDelayTime
    )

    let resolved = gifDuration ?? webpDuration ?? Self.fallbackFrameDuration
    if resolved <= 0 {
      return Self.fallbackFrameDuration
    }
    if resolved < Self.lowDelayFrameThreshold {
      return Self.fallbackFrameDuration
    }
    return max(resolved, Self.minimumFrameDuration)
  }

  private static func decodeFrame(
    from source: CGImageSource,
    at index: Int,
    maxPixelSize: Int?
  ) -> CGImage? {
    if let maxPixelSize, maxPixelSize > 0 {
      let options: [CFString: Any] = [
        kCGImageSourceCreateThumbnailFromImageAlways: true,
        kCGImageSourceShouldCacheImmediately: true,
        kCGImageSourceCreateThumbnailWithTransform: true,
        kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
      ]
      return CGImageSourceCreateThumbnailAtIndex(source, index, options as CFDictionary)
    }

    let options = [kCGImageSourceShouldCacheImmediately: true] as CFDictionary
    return CGImageSourceCreateImageAtIndex(source, index, options)
  }

  private static func parseDuration(
    dictionary: [CFString: Any]?,
    unclampedKey: CFString,
    clampedKey: CFString
  ) -> Double? {
    guard let dictionary else { return nil }
    if let unclamped = numberValue(dictionary[unclampedKey]), unclamped > 0 {
      return unclamped
    }
    if let clamped = numberValue(dictionary[clampedKey]), clamped > 0 {
      return clamped
    }
    return nil
  }

  private static func numberValue(_ value: Any?) -> Double? {
    if let number = value as? NSNumber {
      return number.doubleValue
    }
    if let double = value as? Double {
      return double
    }
    if let float = value as? Float {
      return Double(float)
    }
    return nil
  }
}
