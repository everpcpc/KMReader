import AVFoundation
import Foundation
import ImageIO

actor AnimatedImageVideoTranscoder {
  static let shared = AnimatedImageVideoTranscoder()

  private enum TranscodeResult: Sendable {
    case completed(URL?)
    case timeout
  }

  private static let outputExtension = "mp4"
  private static let timeScale: Int32 = 600
  private static let fallbackFrameDuration: Double = 0.1
  private static let minimumFrameDuration: Double = 1.0 / 60.0
  private static let lowDelayFrameThreshold: Double = 0.011
  private static let transcodeTimeout: TimeInterval = 12

  private let logger = AppLogger(.reader)
  private var transcodeTasks: [URL: Task<URL?, Never>] = [:]

  func prepareVideoURL(for sourceFileURL: URL) async -> URL? {
    if let runningTask = transcodeTasks[sourceFileURL] {
      logger.debug("⏳ [AnimatedVideo] Await running task: \(sourceFileURL.lastPathComponent)")
      return await runningTask.value
    }

    logger.debug("🚀 [AnimatedVideo] Queue task: \(sourceFileURL.lastPathComponent), inFlight=\(transcodeTasks.count)")
    let task = Task<URL?, Never>(priority: .utility) { [weak self, sourceFileURL] in
      guard let self else { return nil }
      return await self.transcodeSerially(sourceFileURL: sourceFileURL)
    }

    transcodeTasks[sourceFileURL] = task
    let result = await task.value
    transcodeTasks.removeValue(forKey: sourceFileURL)
    if let result {
      self.logger.debug("✅ [AnimatedVideo] Ready: \(result.lastPathComponent)")
    } else {
      self.logger.debug("⏭️ [AnimatedVideo] Unavailable: \(sourceFileURL.lastPathComponent)")
    }
    return result
  }

  private func transcodeSerially(sourceFileURL: URL) async -> URL? {
    let logger = self.logger
    let timeoutNanoseconds = UInt64(Self.transcodeTimeout * 1_000_000_000)

    let result = await withTaskGroup(of: TranscodeResult.self, returning: TranscodeResult.self) {
      group in
      group.addTask {
        .completed(Self.transcodeIfNeeded(sourceFileURL: sourceFileURL, logger: logger))
      }
      group.addTask {
        try? await Task.sleep(nanoseconds: timeoutNanoseconds)
        return .timeout
      }

      let firstResult = await group.next() ?? .timeout
      group.cancelAll()
      return firstResult
    }

    switch result {
    case .completed(let outputURL):
      return outputURL
    case .timeout:
      logger.error(
        String(
          format: "❌ [AnimatedVideo] Timeout %@ after %.1fs",
          sourceFileURL.lastPathComponent,
          Self.transcodeTimeout
        )
      )
      return nil
    }
  }

  func cancelAll() {
    guard !transcodeTasks.isEmpty else { return }
    logger.debug("🛑 [AnimatedVideo] Cancel \(transcodeTasks.count) task(s)")
    for (_, task) in transcodeTasks {
      task.cancel()
    }
    transcodeTasks.removeAll()
  }

  nonisolated private static func transcodeIfNeeded(
    sourceFileURL: URL,
    logger: AppLogger
  ) -> URL? {
    let fileManager = FileManager.default
    let outputURL = sidecarVideoURL(for: sourceFileURL)
    let outputDirectory = outputURL.deletingLastPathComponent()
    do {
      try fileManager.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
    } catch {
      logger.error("❌ [AnimatedVideo] Failed to create output directory: \(outputDirectory.path)")
      return nil
    }

    if fileManager.fileExists(atPath: outputURL.path) {
      logger.debug("✅ [AnimatedVideo] Use sidecar cache: \(outputURL.lastPathComponent)")
      return outputURL
    }

    let temporaryOutputURL =
      outputDirectory
      .appendingPathComponent(UUID().uuidString)
      .appendingPathExtension("tmp")
      .appendingPathExtension(outputExtension)

    let startedAt = Date()
    if transcode(sourceFileURL: sourceFileURL, outputURL: temporaryOutputURL, logger: logger) {
      do {
        if fileManager.fileExists(atPath: outputURL.path) {
          try fileManager.removeItem(at: outputURL)
        }
        try fileManager.moveItem(at: temporaryOutputURL, to: outputURL)
        let duration = Date().timeIntervalSince(startedAt)
        logger.debug(
          String(
            format: "💾 [AnimatedVideo] Saved %@ in %.2fs",
            outputURL.lastPathComponent,
            duration
          )
        )
        return outputURL
      } catch {
        logger.error(
          "❌ [AnimatedVideo] Failed to finalize video output for \(sourceFileURL.lastPathComponent): \(error.localizedDescription)"
        )
        try? fileManager.removeItem(at: temporaryOutputURL)
        return nil
      }
    }

    try? fileManager.removeItem(at: temporaryOutputURL)
    logger.debug("⏭️ [AnimatedVideo] Skip transcoding for \(sourceFileURL.lastPathComponent)")
    return nil
  }

  nonisolated private static func sidecarVideoURL(for sourceFileURL: URL) -> URL {
    let directory = sourceFileURL.deletingLastPathComponent()
    let baseName = sourceFileURL.deletingPathExtension().lastPathComponent
    let resolvedBaseName = baseName.hasSuffix("@animated") ? baseName : "\(baseName)@animated"
    return directory.appendingPathComponent(resolvedBaseName).appendingPathExtension(outputExtension)
  }

  nonisolated private static func transcode(
    sourceFileURL: URL,
    outputURL: URL,
    logger: AppLogger
  ) -> Bool {
    if Task.isCancelled {
      return false
    }

    let options = [kCGImageSourceShouldCache: false] as CFDictionary
    guard let source = CGImageSourceCreateWithURL(sourceFileURL as CFURL, options) else {
      logger.debug("⏭️ [AnimatedVideo] Skip \(sourceFileURL.lastPathComponent): create image source failed")
      return false
    }

    let frameCount = CGImageSourceGetCount(source)
    guard frameCount > 1 else {
      logger.debug("⏭️ [AnimatedVideo] Skip \(sourceFileURL.lastPathComponent): frameCount=\(frameCount)")
      return false
    }

    guard let firstFrame = CGImageSourceCreateImageAtIndex(source, 0, options) else {
      logger.debug("⏭️ [AnimatedVideo] Skip \(sourceFileURL.lastPathComponent): decode first frame failed")
      return false
    }

    let outputSize = normalizedOutputSize(from: firstFrame)
    guard outputSize.width > 0, outputSize.height > 0 else {
      logger.debug("⏭️ [AnimatedVideo] Skip \(sourceFileURL.lastPathComponent): invalid output size")
      return false
    }

    let renderColorSpace = preferredRenderColorSpace(from: firstFrame)
    logger.debug(
      "🎞️ [AnimatedVideo] Start \(sourceFileURL.lastPathComponent): frames=\(frameCount), size=\(Int(outputSize.width))x\(Int(outputSize.height)), color=\(colorSpaceLabel(renderColorSpace))"
    )
    let writerSettings = videoWriterSettings(size: outputSize, colorSpace: renderColorSpace)
    guard let writer = try? AVAssetWriter(outputURL: outputURL, fileType: .mp4) else {
      logger.debug("⏭️ [AnimatedVideo] Skip \(sourceFileURL.lastPathComponent): AVAssetWriter init failed")
      return false
    }
    let writerInput = AVAssetWriterInput(mediaType: .video, outputSettings: writerSettings)

    writerInput.expectsMediaDataInRealTime = false
    writerInput.transform = .identity

    let sourceAttributes: [String: Any] = [
      kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA),
      kCVPixelBufferWidthKey as String: outputSize.width,
      kCVPixelBufferHeightKey as String: outputSize.height,
      kCVPixelBufferCGImageCompatibilityKey as String: true,
      kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
      kCVPixelBufferIOSurfacePropertiesKey as String: [:],
    ]

    let adaptor = AVAssetWriterInputPixelBufferAdaptor(
      assetWriterInput: writerInput,
      sourcePixelBufferAttributes: sourceAttributes
    )

    guard writer.canAdd(writerInput) else {
      logger.debug("⏭️ [AnimatedVideo] Skip \(sourceFileURL.lastPathComponent): writer input unavailable")
      return false
    }
    writer.add(writerInput)

    guard writer.startWriting() else {
      logger.debug(
        "❌ [AnimatedVideo] Start writing failed for \(sourceFileURL.lastPathComponent): \(writer.error?.localizedDescription ?? "unknown")"
      )
      return false
    }
    writer.startSession(atSourceTime: .zero)

    var presentationTime = CMTime.zero
    var renderedFrameCount = 0
    var skippedFrameCount = 0
    let frameOptions =
      [
        kCGImageSourceShouldCache: false,
        kCGImageSourceShouldCacheImmediately: false,
      ] as CFDictionary

    for frameIndex in 0..<frameCount {
      if Task.isCancelled {
        writerInput.markAsFinished()
        writer.cancelWriting()
        return false
      }

      guard
        let frameImage = CGImageSourceCreateImageAtIndex(source, frameIndex, frameOptions),
        let pixelBuffer = makePixelBuffer(
          from: frameImage,
          size: outputSize,
          adaptor: adaptor,
          colorSpace: renderColorSpace
        )
      else {
        skippedFrameCount += 1
        continue
      }

      while !writerInput.isReadyForMoreMediaData {
        if Task.isCancelled || writer.status == .failed || writer.status == .cancelled {
          writerInput.markAsFinished()
          writer.cancelWriting()
          return false
        }
        Thread.sleep(forTimeInterval: 0.0015)
      }

      let appended = adaptor.append(pixelBuffer, withPresentationTime: presentationTime)
      if !appended {
        logger.debug(
          "❌ [AnimatedVideo] Append failed for \(sourceFileURL.lastPathComponent): frame=\(frameIndex), error=\(writer.error?.localizedDescription ?? "unknown")"
        )
        writerInput.markAsFinished()
        writer.cancelWriting()
        return false
      }
      renderedFrameCount += 1

      let frameDuration = frameDuration(source: source, frameIndex: frameIndex)
      let durationTime = CMTime(seconds: frameDuration, preferredTimescale: timeScale)
      presentationTime = presentationTime + durationTime
    }

    if Task.isCancelled {
      writerInput.markAsFinished()
      writer.cancelWriting()
      return false
    }

    guard renderedFrameCount > 0 else {
      logger.debug("⏭️ [AnimatedVideo] Skip \(sourceFileURL.lastPathComponent): no renderable frames")
      writerInput.markAsFinished()
      writer.cancelWriting()
      return false
    }

    writerInput.markAsFinished()

    let semaphore = DispatchSemaphore(value: 0)
    writer.finishWriting {
      semaphore.signal()
    }
    while semaphore.wait(timeout: .now() + .milliseconds(20)) == .timedOut {
      if Task.isCancelled {
        writer.cancelWriting()
        return false
      }
    }

    if writer.status == .completed {
      logger.debug(
        "✅ [AnimatedVideo] Encoded \(sourceFileURL.lastPathComponent): rendered=\(renderedFrameCount), skipped=\(skippedFrameCount)"
      )
      return true
    }

    logger.debug(
      "❌ [AnimatedVideo] Finish failed for \(sourceFileURL.lastPathComponent): status=\(writer.status.rawValue), error=\(writer.error?.localizedDescription ?? "unknown")"
    )
    return false
  }

  nonisolated private static func normalizedOutputSize(from image: CGImage) -> CGSize {
    let width = max((image.width / 2) * 2, 2)
    let height = max((image.height / 2) * 2, 2)
    return CGSize(width: width, height: height)
  }

  nonisolated private static func preferredRenderColorSpace(from image: CGImage) -> CGColorSpace {
    if let sourceColorSpace = image.colorSpace, sourceColorSpace.model == .rgb {
      return sourceColorSpace
    }
    return CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
  }

  nonisolated private static func colorSpaceLabel(_ colorSpace: CGColorSpace) -> String {
    colorSpace.name.map { $0 as String } ?? "unknown"
  }

  nonisolated private static func videoWriterSettings(size: CGSize, colorSpace: CGColorSpace) -> [String: Any] {
    let width = Int(size.width)
    let height = Int(size.height)
    let pixels = max(width * height, 1)
    let bitrate = max(pixels * 4, 1_500_000)

    var settings: [String: Any] = [
      AVVideoCodecKey: AVVideoCodecType.h264,
      AVVideoWidthKey: width,
      AVVideoHeightKey: height,
      AVVideoCompressionPropertiesKey: [
        AVVideoAverageBitRateKey: bitrate,
        AVVideoMaxKeyFrameIntervalDurationKey: 1,
      ],
    ]
    settings[AVVideoColorPropertiesKey] = videoColorProperties(for: colorSpace)
    return settings
  }

  nonisolated private static func videoColorProperties(for colorSpace: CGColorSpace) -> [String: String] {
    let displayP3Name = CGColorSpace(name: CGColorSpace.displayP3)?.name
    if colorSpace.name == displayP3Name {
      return [
        AVVideoColorPrimariesKey: AVVideoColorPrimaries_P3_D65,
        AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
        AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2,
      ]
    }

    return [
      AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
      AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
      AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2,
    ]
  }

  nonisolated private static func makePixelBuffer(
    from image: CGImage,
    size: CGSize,
    adaptor: AVAssetWriterInputPixelBufferAdaptor,
    colorSpace: CGColorSpace
  ) -> CVPixelBuffer? {
    guard let pixelBufferPool = adaptor.pixelBufferPool else {
      return nil
    }

    var pixelBuffer: CVPixelBuffer?
    let creationStatus = CVPixelBufferPoolCreatePixelBuffer(
      kCFAllocatorDefault,
      pixelBufferPool,
      &pixelBuffer
    )
    guard creationStatus == kCVReturnSuccess, let pixelBuffer else {
      return nil
    }

    CVPixelBufferLockBaseAddress(pixelBuffer, [])
    defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }

    guard
      let context = CGContext(
        data: CVPixelBufferGetBaseAddress(pixelBuffer),
        width: Int(size.width),
        height: Int(size.height),
        bitsPerComponent: 8,
        bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
        space: colorSpace,
        bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue
      )
    else {
      return nil
    }

    context.clear(CGRect(origin: .zero, size: size))
    context.interpolationQuality = .high
    context.draw(image, in: CGRect(origin: .zero, size: size))

    return pixelBuffer
  }

  nonisolated private static func frameDuration(source: CGImageSource, frameIndex: Int) -> Double {
    guard
      let properties = CGImageSourceCopyPropertiesAtIndex(source, frameIndex, nil) as? [CFString: Any]
    else {
      return fallbackFrameDuration
    }

    let gifDuration = frameDuration(
      dictionary: properties[kCGImagePropertyGIFDictionary] as? [CFString: Any],
      unclampedKey: kCGImagePropertyGIFUnclampedDelayTime,
      clampedKey: kCGImagePropertyGIFDelayTime
    )

    let webpDuration = frameDuration(
      dictionary: properties[kCGImagePropertyWebPDictionary] as? [CFString: Any],
      unclampedKey: kCGImagePropertyWebPUnclampedDelayTime,
      clampedKey: kCGImagePropertyWebPDelayTime
    )

    let resolved = gifDuration ?? webpDuration ?? fallbackFrameDuration
    if resolved <= 0 {
      return fallbackFrameDuration
    }
    if resolved < lowDelayFrameThreshold {
      return fallbackFrameDuration
    }
    return max(resolved, minimumFrameDuration)
  }

  nonisolated private static func frameDuration(
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

  nonisolated private static func numberValue(_ value: Any?) -> Double? {
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
