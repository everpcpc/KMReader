import CoreGraphics
import Foundation

actor AnimatedImageFrameStore {
  private let decoder: AnimatedImageFrameDecoder

  init?(fileURL: URL) {
    guard let decoder = AnimatedImageFrameDecoder(fileURL: fileURL) else {
      return nil
    }
    self.decoder = decoder
  }

  func frameCount() -> Int {
    decoder.frameCount
  }

  func frameDurations() -> [TimeInterval] {
    decoder.frameDurations
  }

  func posterFrame(maxPixelSize: Int?) -> CGImage? {
    decoder.decodeFrame(at: 0, maxPixelSize: maxPixelSize) ?? decoder.posterFrame
  }

  func decodeFrame(at index: Int, maxPixelSize: Int?) -> CGImage? {
    decoder.decodeFrame(at: index, maxPixelSize: maxPixelSize)
  }
}
