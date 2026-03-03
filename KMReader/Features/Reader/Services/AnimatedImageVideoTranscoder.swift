import AVFoundation
import Foundation
import ImageIO

actor AnimatedImageVideoTranscoder {
  static let shared = AnimatedImageVideoTranscoder()

  private static let outputExtension = "mp4"
  private static let timeScale: Int32 = 600
  private static let fallbackFrameDuration: Double = 0.1
  private static let minimumFrameDuration: Double = 1.0 / 30.0
  private static let lowDelayFrameThreshold: Double = 0.011
  private static let writerBackPressureSleepInterval: TimeInterval = 0.004
  private static let progressReportStep: Double = 0.01
  private static let highFrameRateDropThreshold: Double = 1.0 / 45.0
  private static let maxOutputDimension = 1920

  private let logger = AppLogger(.reader)
  private var transcodeTasks: [URL: Task<URL?, Never>] = [:]
  private var transcodeProgress: [URL: Double] = [:]

  func prepareVideoURL(for sourceFileURL: URL) async -> URL? {
    if let runningTask = transcodeTasks[sourceFileURL] {
      logger.debug("⏳ [AnimatedVideo] Await running task: \(sourceFileURL.lastPathComponent)")
      return await runningTask.value
    }

    logger.debug("🚀 [AnimatedVideo] Queue task: \(sourceFileURL.lastPathComponent), inFlight=\(transcodeTasks.count)")
    let logger = self.logger
    let transcoder = self
    transcodeProgress[sourceFileURL] = 0
    let task: Task<URL?, Never> = Task.detached(priority: .userInitiated) {
      [sourceFileURL, logger, transcoder] () -> URL? in
      guard !Task.isCancelled else { return nil }
      let reportProgress: @Sendable (Double) -> Void = { [sourceFileURL, transcoder] progress in
        Task {
          await transcoder.updateProgress(progress, for: sourceFileURL)
        }
      }
      return Self.transcodeIfNeeded(
        sourceFileURL: sourceFileURL,
        logger: logger,
        reportProgress: reportProgress
      )
    }

    transcodeTasks[sourceFileURL] = task
    let result = await task.value
    transcodeTasks.removeValue(forKey: sourceFileURL)
    transcodeProgress.removeValue(forKey: sourceFileURL)
    if let result {
      self.logger.debug("✅ [AnimatedVideo] Ready: \(result.lastPathComponent)")
    } else if task.isCancelled {
      self.logger.debug("⏭️ [AnimatedVideo] Cancelled \(sourceFileURL.lastPathComponent)")
    } else {
      self.logger.debug("⏭️ [AnimatedVideo] Unavailable: \(sourceFileURL.lastPathComponent)")
    }
    return result
  }

  func cancelAll() {
    guard !transcodeTasks.isEmpty else { return }
    logger.debug("🛑 [AnimatedVideo] Cancel \(transcodeTasks.count) task(s)")
    for (_, task) in transcodeTasks {
      task.cancel()
    }
    transcodeTasks.removeAll()
    transcodeProgress.removeAll()
  }

  func cancelAll(exceptSourceFileURLs keptSourceFileURLs: Set<URL>) {
    guard !transcodeTasks.isEmpty else { return }
    guard !keptSourceFileURLs.isEmpty else {
      cancelAll()
      return
    }

    let cancelledSourceFileURLs = transcodeTasks.keys.filter { !keptSourceFileURLs.contains($0) }
    guard !cancelledSourceFileURLs.isEmpty else { return }

    logger.debug(
      "🛑 [AnimatedVideo] Cancel \(cancelledSourceFileURLs.count) task(s), keep=\(keptSourceFileURLs.count)"
    )
    for sourceFileURL in cancelledSourceFileURLs {
      transcodeTasks[sourceFileURL]?.cancel()
      transcodeTasks.removeValue(forKey: sourceFileURL)
      transcodeProgress.removeValue(forKey: sourceFileURL)
    }
  }

  func progress(for sourceFileURL: URL) -> Double? {
    transcodeProgress[sourceFileURL]
  }

  private func updateProgress(_ progress: Double, for sourceFileURL: URL) {
    let clampedProgress = min(max(progress, 0), 1)
    let previousProgress = transcodeProgress[sourceFileURL] ?? -1
    guard
      clampedProgress == 1
        || previousProgress < 0
        || clampedProgress - previousProgress >= Self.progressReportStep
    else { return }
    transcodeProgress[sourceFileURL] = clampedProgress
  }

  nonisolated private static func transcodeIfNeeded(
    sourceFileURL: URL,
    logger: AppLogger,
    reportProgress: @escaping @Sendable (Double) -> Void
  ) -> URL? {
    reportProgress(0)
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
      reportProgress(1)
      logger.debug("✅ [AnimatedVideo] Use sidecar cache: \(outputURL.lastPathComponent)")
      return outputURL
    }

    let temporaryOutputURL =
      outputDirectory
      .appendingPathComponent(UUID().uuidString)
      .appendingPathExtension("tmp")
      .appendingPathExtension(outputExtension)

    let startedAt = Date()
    if transcode(
      sourceFileURL: sourceFileURL,
      outputURL: temporaryOutputURL,
      logger: logger,
      reportProgress: reportProgress
    ) {
      do {
        if fileManager.fileExists(atPath: outputURL.path) {
          try fileManager.removeItem(at: outputURL)
        }
        try fileManager.moveItem(at: temporaryOutputURL, to: outputURL)
        reportProgress(1)
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
    logger: AppLogger,
    reportProgress: @escaping @Sendable (Double) -> Void
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

    let outputSize = normalizedOutputSize(from: firstFrame, maxDimension: maxOutputDimension)
    guard outputSize.width > 0, outputSize.height > 0 else {
      logger.debug("⏭️ [AnimatedVideo] Skip \(sourceFileURL.lastPathComponent): invalid output size")
      return false
    }
    let sourceSize = CGSize(width: firstFrame.width, height: firstFrame.height)
    let shouldDownsampleFrames = sourceSize.width > outputSize.width || sourceSize.height > outputSize.height

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
    var waitForWriterDuration: TimeInterval = 0
    let encodeStartedAt = Date()
    let frameOptions =
      [
        kCGImageSourceShouldCache: false,
        kCGImageSourceShouldCacheImmediately: false,
      ] as CFDictionary
    let thumbnailOptions: CFDictionary? =
      shouldDownsampleFrames
      ? [
        kCGImageSourceShouldCache: false,
        kCGImageSourceShouldCacheImmediately: false,
        kCGImageSourceCreateThumbnailFromImageAlways: true,
        kCGImageSourceCreateThumbnailWithTransform: true,
        kCGImageSourceThumbnailMaxPixelSize: max(Int(outputSize.width), Int(outputSize.height)),
      ] as CFDictionary : nil
    var droppedHighFPSFrameCount = 0

    for frameIndex in 0..<frameCount {
      if Task.isCancelled {
        writerInput.markAsFinished()
        writer.cancelWriting()
        return false
      }
      let currentFrameDuration = frameDuration(source: source, frameIndex: frameIndex)
      let durationTime = CMTime(seconds: currentFrameDuration, preferredTimescale: timeScale)
      let shouldDropHighFPSFrame =
        currentFrameDuration < highFrameRateDropThreshold && !frameIndex.isMultiple(of: 2)
      if shouldDropHighFPSFrame {
        droppedHighFPSFrameCount += 1
        presentationTime = presentationTime + durationTime
        reportProgress(Double(frameIndex + 1) / Double(frameCount))
        continue
      }

      guard
        let frameImage = frameImageAtIndex(
          source: source,
          frameIndex: frameIndex,
          frameOptions: frameOptions,
          thumbnailOptions: thumbnailOptions
        ),
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
        Thread.sleep(forTimeInterval: writerBackPressureSleepInterval)
        waitForWriterDuration += writerBackPressureSleepInterval
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

      presentationTime = presentationTime + durationTime
      reportProgress(Double(frameIndex + 1) / Double(frameCount))
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
    let finishStartedAt = Date()
    let encodeLoopDuration = finishStartedAt.timeIntervalSince(encodeStartedAt)
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
      let finishDuration = Date().timeIntervalSince(finishStartedAt)
      logger.debug(
        "✅ [AnimatedVideo] Encoded \(sourceFileURL.lastPathComponent): rendered=\(renderedFrameCount), skipped=\(skippedFrameCount), droppedHighFPS=\(droppedHighFPSFrameCount)"
      )
      logger.debug(
        String(
          format: "⏱️ [AnimatedVideo] Timing %@: encode=%.2fs, wait=%.2fs, finish=%.2fs",
          sourceFileURL.lastPathComponent,
          encodeLoopDuration,
          waitForWriterDuration,
          finishDuration
        )
      )
      reportProgress(1)
      return true
    }

    logger.debug(
      "❌ [AnimatedVideo] Finish failed for \(sourceFileURL.lastPathComponent): status=\(writer.status.rawValue), error=\(writer.error?.localizedDescription ?? "unknown")"
    )
    return false
  }

  nonisolated private static func normalizedOutputSize(from image: CGImage, maxDimension: Int) -> CGSize {
    let sourceWidth = CGFloat(image.width)
    let sourceHeight = CGFloat(image.height)
    guard sourceWidth > 0, sourceHeight > 0 else {
      return CGSize(width: 2, height: 2)
    }

    let longSide = max(sourceWidth, sourceHeight)
    let scale = min(1, CGFloat(maxDimension) / longSide)
    let width = max((Int((sourceWidth * scale).rounded()) / 2) * 2, 2)
    let height = max((Int((sourceHeight * scale).rounded()) / 2) * 2, 2)
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
    let bitrate = min(max(pixels * 2, 1_000_000), 8_000_000)

    var settings: [String: Any] = [
      AVVideoCodecKey: AVVideoCodecType.h264,
      AVVideoWidthKey: width,
      AVVideoHeightKey: height,
      AVVideoCompressionPropertiesKey: [
        AVVideoAverageBitRateKey: bitrate,
        AVVideoMaxKeyFrameIntervalDurationKey: 1,
        AVVideoExpectedSourceFrameRateKey: 30,
        AVVideoAllowFrameReorderingKey: false,
        AVVideoH264EntropyModeKey: AVVideoH264EntropyModeCAVLC,
      ],
    ]
    settings[AVVideoColorPropertiesKey] = videoColorProperties(for: colorSpace)
    return settings
  }

  nonisolated private static func frameImageAtIndex(
    source: CGImageSource,
    frameIndex: Int,
    frameOptions: CFDictionary,
    thumbnailOptions: CFDictionary?
  ) -> CGImage? {
    if let thumbnailOptions,
      let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, frameIndex, thumbnailOptions)
    {
      return thumbnail
    }
    return CGImageSourceCreateImageAtIndex(source, frameIndex, frameOptions)
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
    context.interpolationQuality = .medium
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
