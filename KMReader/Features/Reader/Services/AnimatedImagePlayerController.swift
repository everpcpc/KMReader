import Foundation
import QuartzCore

#if os(macOS)
  import AppKit
#endif

#if os(iOS) || os(macOS)

  @MainActor
  final class AnimatedImagePlayerController {
    private static let bufferSize = 5

    private var decoder: AnimatedImageFrameDecoder?
    private var displayLink: CADisplayLink?
    private weak var targetLayer: CALayer?

    private var frameBuffer: [Int: CGImage] = [:]
    private var currentFrameIndex = 0
    private var elapsedTime: TimeInterval = 0
    private var lastTimestamp: CFTimeInterval = 0
    private var isRunning = false

    func start(sourceFileURL: URL, targetLayer: CALayer) {
      if isRunning, self.targetLayer === targetLayer,
        decoder != nil
      {
        return
      }

      stop()

      guard let decoder = AnimatedImageFrameDecoder(fileURL: sourceFileURL) else {
        return
      }

      self.decoder = decoder
      self.targetLayer = targetLayer
      self.currentFrameIndex = 0
      self.elapsedTime = 0
      self.lastTimestamp = 0
      self.frameBuffer.removeAll()

      if let firstFrame = decoder.decodeFrame(at: 0) {
        frameBuffer[0] = firstFrame
        targetLayer.contents = firstFrame
      }

      prefetchFrames(around: 0, decoder: decoder)

      let displayLinkTarget = DisplayLinkTarget(self)
      #if os(iOS)
        let link = CADisplayLink(target: displayLinkTarget, selector: #selector(DisplayLinkTarget.tick(_:)))
      #else
        guard
          let link = NSScreen.main?.displayLink(
            target: displayLinkTarget,
            selector: #selector(DisplayLinkTarget.tick(_:))
          )
        else { return }
      #endif
      link.add(to: .main, forMode: .common)
      displayLink = link
      isRunning = true
    }

    func stop() {
      displayLink?.invalidate()
      displayLink = nil
      decoder = nil
      frameBuffer.removeAll()
      currentFrameIndex = 0
      elapsedTime = 0
      lastTimestamp = 0
      isRunning = false
    }

    fileprivate func tick(_ link: CADisplayLink) {
      guard let decoder, let targetLayer else {
        stop()
        return
      }

      let timestamp = link.timestamp
      if lastTimestamp == 0 {
        lastTimestamp = timestamp
        return
      }

      let delta = timestamp - lastTimestamp
      lastTimestamp = timestamp
      elapsedTime += delta

      let frameDuration = decoder.frameDuration(at: currentFrameIndex)
      guard elapsedTime >= frameDuration else { return }

      elapsedTime -= frameDuration
      if elapsedTime > frameDuration {
        elapsedTime = 0
      }

      let nextIndex = (currentFrameIndex + 1) % decoder.frameCount
      evictDistantFrames(from: nextIndex, decoder: decoder)

      if let frame = frameBuffer[nextIndex] {
        targetLayer.contents = frame
      } else if let frame = decoder.decodeFrame(at: nextIndex) {
        frameBuffer[nextIndex] = frame
        targetLayer.contents = frame
      }

      currentFrameIndex = nextIndex
      prefetchFrames(around: nextIndex, decoder: decoder)
    }

    private func prefetchFrames(around index: Int, decoder: AnimatedImageFrameDecoder) {
      let count = decoder.frameCount
      for offset in 1...Self.bufferSize {
        let idx = (index + offset) % count
        guard frameBuffer[idx] == nil else { continue }
        if let frame = decoder.decodeFrame(at: idx) {
          frameBuffer[idx] = frame
        }
      }
    }

    private func evictDistantFrames(from currentIndex: Int, decoder: AnimatedImageFrameDecoder) {
      let count = decoder.frameCount
      let keepRange = Self.bufferSize + 1
      guard frameBuffer.count > keepRange else { return }
      let keysToRemove = frameBuffer.keys.filter { key in
        let distance = (key - currentIndex + count) % count
        return distance > Self.bufferSize
      }
      for key in keysToRemove {
        frameBuffer.removeValue(forKey: key)
      }
    }
  }

  private final class DisplayLinkTarget {
    private weak var controller: AnimatedImagePlayerController?

    init(_ controller: AnimatedImagePlayerController) {
      self.controller = controller
    }

    @objc func tick(_ link: CADisplayLink) {
      guard let controller else {
        link.invalidate()
        return
      }
      controller.tick(link)
    }
  }

#endif
