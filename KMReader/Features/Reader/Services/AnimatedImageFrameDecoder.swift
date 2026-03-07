import Foundation
import ImageIO

@MainActor
final class AnimatedImageFrameDecoder {
  private static let fallbackFrameDuration: Double = 0.1
  private static let minimumFrameDuration: Double = 1.0 / 30.0
  private static let lowDelayFrameThreshold: Double = 0.011

  private let source: CGImageSource
  let frameCount: Int

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
  }

  func frameDuration(at index: Int) -> TimeInterval {
    guard index >= 0, index < frameCount else {
      return Self.fallbackFrameDuration
    }
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

  func decodeFrame(at index: Int) -> CGImage? {
    guard index >= 0, index < frameCount else { return nil }
    let options = [kCGImageSourceShouldCache: false] as CFDictionary
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
