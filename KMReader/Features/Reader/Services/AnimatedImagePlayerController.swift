import Foundation
import QuartzCore
import SDWebImage

#if os(iOS) || os(tvOS)
  import UIKit
#elseif os(macOS)
  import AppKit
#endif

@MainActor
final class AnimatedImagePlayerController {
  private var player: SDAnimatedImagePlayer?
  private var animatedImage: SDAnimatedImage?
  private var currentSourceFileURL: URL?
  private weak var targetLayer: CALayer?
  private var startupTask: Task<Void, Never>?
  private var targetMaxPixelSize: Int?
  private var playbackGeneration: UInt64 = 0

  func start(sourceFileURL: URL, targetLayer: CALayer) {
    let targetMaxPixelSize = resolvedMaxPixelSize(for: targetLayer)
    if self.targetLayer === targetLayer,
      currentSourceFileURL == sourceFileURL,
      self.targetMaxPixelSize == targetMaxPixelSize,
      player != nil || startupTask != nil
    {
      return
    }

    stop()

    self.currentSourceFileURL = sourceFileURL
    self.targetLayer = targetLayer
    self.targetMaxPixelSize = targetMaxPixelSize
    let generation = nextPlaybackGeneration()

    startupTask = Task.detached(priority: .userInitiated) { [sourceFileURL, targetMaxPixelSize] in
      let animatedImage = AnimatedImageSupport.loadAnimatedImage(
        fileURL: sourceFileURL,
        maxPixelSize: targetMaxPixelSize
      )

      await MainActor.run { [weak self] in
        guard let self else { return }
        guard self.playbackGeneration == generation else { return }
        guard self.currentSourceFileURL == sourceFileURL else { return }

        self.startupTask = nil

        guard
          let animatedImage,
          animatedImage.animatedImageFrameCount > 1,
          let player = SDAnimatedImagePlayer(provider: animatedImage)
        else {
          return
        }

        self.animatedImage = animatedImage
        self.player = player
        self.targetLayer?.contents = Self.cgImage(from: animatedImage)

        player.runLoopMode = .common
        player.animationFrameHandler = { [weak self] _, frame in
          guard let self else { return }
          guard self.playbackGeneration == generation else { return }
          self.targetLayer?.contents = Self.cgImage(from: frame)
        }
        player.startPlaying()
      }
    }
  }

  func stop() {
    _ = nextPlaybackGeneration()
    startupTask?.cancel()
    startupTask = nil
    player?.animationFrameHandler = nil
    player?.stopPlaying()
    player?.clearFrameBuffer()
    player = nil
    animatedImage = nil
    targetLayer?.contents = nil
    currentSourceFileURL = nil
    targetLayer = nil
    targetMaxPixelSize = nil
  }

  private func resolvedMaxPixelSize(for targetLayer: CALayer) -> Int? {
    let bounds = targetLayer.bounds
    guard bounds.width > 0, bounds.height > 0 else { return nil }
    let scale = targetLayer.contentsScale > 0 ? targetLayer.contentsScale : 2
    let maxDimension = max(bounds.width, bounds.height) * scale
    guard maxDimension.isFinite, maxDimension > 0 else { return nil }
    return Int(ceil(maxDimension))
  }

  private static func cgImage(from image: PlatformImage?) -> CGImage? {
    #if os(macOS)
      return image?.cgImage(forProposedRect: nil, context: nil, hints: nil)
    #else
      return image?.cgImage
    #endif
  }

  private func nextPlaybackGeneration() -> UInt64 {
    playbackGeneration &+= 1
    return playbackGeneration
  }
}
