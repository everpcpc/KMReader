import Foundation
import QuartzCore

#if os(macOS)
  import AppKit
#endif

@MainActor
final class AnimatedImagePlayerController {
  private static let bufferSize = 5
  private static let targetFramesPerSecond = 30

  private var frameStore: AnimatedImageFrameStore?
  private var displayLink: CADisplayLink?
  private var currentSourceFileURL: URL?
  private weak var targetLayer: CALayer?

  private var frameBuffer: [Int: CGImage] = [:]
  private var frameDurations: [TimeInterval] = []
  private var frameCount = 0
  private var frameDecodeTasks: [Int: Task<Void, Never>] = [:]
  private var startupTask: Task<Void, Never>?
  private var startupGeneration: UInt64?
  private var currentFrameIndex = 0
  private var elapsedTime: TimeInterval = 0
  private var lastTimestamp: CFTimeInterval = 0
  private var targetMaxPixelSize: Int?
  private var playbackGeneration: UInt64 = 0
  private var isRunning = false

  func start(sourceFileURL: URL, targetLayer: CALayer) {
    let targetMaxPixelSize = resolvedMaxPixelSize(for: targetLayer)
    if self.targetLayer === targetLayer,
      currentSourceFileURL == sourceFileURL,
      self.targetMaxPixelSize == targetMaxPixelSize,
      isRunning || startupGeneration != nil
    {
      return
    }

    stop()

    self.currentSourceFileURL = sourceFileURL
    self.targetLayer = targetLayer
    self.targetMaxPixelSize = targetMaxPixelSize
    self.currentFrameIndex = 0
    self.elapsedTime = 0
    self.lastTimestamp = 0
    self.frameBuffer.removeAll()
    self.frameDurations.removeAll()
    self.frameCount = 0
    let generation = nextPlaybackGeneration()
    self.startupGeneration = generation

    startupTask = Task.detached(priority: .userInitiated) { [sourceFileURL, targetMaxPixelSize] in
      guard let frameStore = AnimatedImageFrameStore(fileURL: sourceFileURL) else {
        await MainActor.run { [weak self] in
          guard let self else { return }
          guard self.playbackGeneration == generation else { return }
          self.startupGeneration = nil
          self.startupTask = nil
        }
        return
      }

      let frameDurations = await frameStore.frameDurations()
      let frameCount = await frameStore.frameCount()
      let posterFrame = await frameStore.posterFrame(maxPixelSize: targetMaxPixelSize)

      await MainActor.run { [weak self] in
        guard let self else { return }
        guard self.playbackGeneration == generation else { return }
        guard self.currentSourceFileURL == sourceFileURL else { return }

        self.startupGeneration = nil
        self.startupTask = nil
        self.frameStore = frameStore
        self.frameDurations = frameDurations
        self.frameCount = frameCount

        if let posterFrame {
          self.frameBuffer[0] = posterFrame
          self.targetLayer?.contents = posterFrame
        }

        self.startDisplayLinkIfNeeded()
        self.isRunning = true
        self.requestFrames(around: 0)
      }
    }
  }

  func stop() {
    _ = nextPlaybackGeneration()
    startupTask?.cancel()
    startupTask = nil
    startupGeneration = nil
    for task in frameDecodeTasks.values {
      task.cancel()
    }
    frameDecodeTasks.removeAll()
    displayLink?.invalidate()
    displayLink = nil
    targetLayer?.contents = nil
    frameStore = nil
    currentSourceFileURL = nil
    targetLayer = nil
    frameBuffer.removeAll()
    frameDurations.removeAll()
    frameCount = 0
    currentFrameIndex = 0
    elapsedTime = 0
    lastTimestamp = 0
    targetMaxPixelSize = nil
    isRunning = false
  }

  fileprivate func tick(_ link: CADisplayLink) {
    guard frameStore != nil, frameCount > 0, let targetLayer else {
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

    let frameDuration = resolvedFrameDuration(at: currentFrameIndex)
    guard elapsedTime >= frameDuration else { return }

    let nextIndex = (currentFrameIndex + 1) % frameCount
    guard let frame = frameBuffer[nextIndex] else {
      requestFrameIfNeeded(at: nextIndex, priority: .userInitiated)
      requestFrames(around: currentFrameIndex)
      elapsedTime = min(elapsedTime, frameDuration)
      return
    }

    elapsedTime -= frameDuration
    if elapsedTime > frameDuration {
      elapsedTime = frameDuration
    }

    targetLayer.contents = frame
    currentFrameIndex = nextIndex
    evictDistantFrames(from: nextIndex)
    requestFrames(around: nextIndex)
  }

  private func startDisplayLinkIfNeeded() {
    guard displayLink == nil else { return }
    let displayLinkTarget = DisplayLinkTarget(self)
    #if os(macOS)
      guard
        let link = NSScreen.main?.displayLink(
          target: displayLinkTarget,
          selector: #selector(DisplayLinkTarget.tick(_:))
        )
      else { return }
    #else
      let link = CADisplayLink(target: displayLinkTarget, selector: #selector(DisplayLinkTarget.tick(_:)))
    #endif
    let frameRate = Float(Self.targetFramesPerSecond)
    link.preferredFrameRateRange = CAFrameRateRange(
      minimum: frameRate,
      maximum: frameRate,
      preferred: frameRate
    )
    link.add(to: .main, forMode: .common)
    displayLink = link
  }

  private func requestFrames(around index: Int) {
    guard frameCount > 0 else { return }
    requestFrameIfNeeded(at: index, priority: .utility)
    guard Self.bufferSize > 0 else { return }
    for offset in 1...Self.bufferSize {
      let nextIndex = (index + offset) % frameCount
      requestFrameIfNeeded(at: nextIndex, priority: .utility)
    }
  }

  private func requestFrameIfNeeded(at index: Int, priority: TaskPriority) {
    guard frameStore != nil else { return }
    guard index >= 0, index < frameCount else { return }
    guard frameBuffer[index] == nil else { return }
    guard frameDecodeTasks[index] == nil else { return }

    let generation = playbackGeneration
    let maxPixelSize = targetMaxPixelSize
    let store = frameStore
    frameDecodeTasks[index] = Task.detached(priority: priority) { [store] in
      guard let store else { return }
      let frame = await store.decodeFrame(at: index, maxPixelSize: maxPixelSize)
      await MainActor.run { [weak self] in
        guard let self else { return }
        guard self.playbackGeneration == generation else { return }
        self.frameDecodeTasks.removeValue(forKey: index)
        guard let frame else { return }
        self.frameBuffer[index] = frame
      }
    }
  }

  private func evictDistantFrames(from currentIndex: Int) {
    guard frameCount > 0 else { return }
    let keepRange = Self.bufferSize + 1
    guard frameBuffer.count > keepRange || frameDecodeTasks.count > keepRange else { return }
    let keysToRemove = Set(frameBuffer.keys).union(frameDecodeTasks.keys).filter { key in
      let distance = (key - currentIndex + frameCount) % frameCount
      return distance > Self.bufferSize
    }
    for key in keysToRemove {
      frameBuffer.removeValue(forKey: key)
      frameDecodeTasks[key]?.cancel()
      frameDecodeTasks.removeValue(forKey: key)
    }
  }

  private func resolvedFrameDuration(at index: Int) -> TimeInterval {
    guard index >= 0, index < frameDurations.count else {
      return AnimatedImageFrameDecoder.frameDurationFallback
    }
    return frameDurations[index]
  }

  private func resolvedMaxPixelSize(for targetLayer: CALayer) -> Int? {
    let bounds = targetLayer.bounds
    guard bounds.width > 0, bounds.height > 0 else { return nil }
    let scale = targetLayer.contentsScale > 0 ? targetLayer.contentsScale : 2
    let maxDimension = max(bounds.width, bounds.height) * scale
    guard maxDimension.isFinite, maxDimension > 0 else { return nil }
    return Int(ceil(maxDimension))
  }

  private func nextPlaybackGeneration() -> UInt64 {
    playbackGeneration &+= 1
    return playbackGeneration
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
