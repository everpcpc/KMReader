#if os(iOS) || os(tvOS)
  import CoreML
  import Foundation

  actor ReaderUpscaleModelManager {
    static let shared = ReaderUpscaleModelManager()

    private let logger = AppLogger(.reader)
    private let descriptor = ReaderUpscaleModelDescriptor.defaultWaifu2x
    private let maxConcurrentTasks = 2

    private var modelCache: [String: any ReaderImageProcessingModel] = [:]
    private var runningTasks = 0
    private var waitQueue: [CheckedContinuation<Void, Never>] = []
    private var hasLoggedMissingDescriptor = false

    func activeDescriptor() -> ReaderUpscaleModelDescriptor? {
      resolveModelURL(descriptor: descriptor) == nil ? nil : descriptor
    }

    func modelAvailability() -> (isReady: Bool, isDownloading: Bool, errorMessage: String?) {
      let isReady = resolveModelURL(descriptor: descriptor) != nil
      let message = isReady ? nil : "Built-in waifu2x model is unavailable"
      return (isReady, false, message)
    }

    func ensureModelReady() async -> Bool {
      resolveModelURL(descriptor: descriptor) != nil
    }

    func process(_ image: CGImage) async -> CGImage? {
      guard !Task.isCancelled else { return nil }
      guard let activeDescriptor = activeDescriptor() else {
        if !hasLoggedMissingDescriptor {
          logger.error("[Upscale] Built-in waifu2x model is unavailable")
          hasLoggedMissingDescriptor = true
        }
        return nil
      }
      hasLoggedMissingDescriptor = false

      let model: (any ReaderImageProcessingModel)
      do {
        guard let loadedModel = try await loadModel(descriptor: activeDescriptor) else {
          logger.debug("⏭️ [Upscale] Skip processing because model file is unavailable: \(activeDescriptor.file)")
          return nil
        }
        model = loadedModel
      } catch {
        logger.error("[Upscale] Failed to load model \(activeDescriptor.file): \(error.localizedDescription)")
        return nil
      }

      guard !Task.isCancelled else { return nil }
      await acquireSlot()
      defer { releaseSlot() }

      guard !Task.isCancelled else { return nil }
      let output = await model.process(image)
      if output == nil {
        logger.debug("⏭️ [Upscale] Model returned nil output: \(activeDescriptor.file)")
      }
      return output
    }

    private func acquireSlot() async {
      if runningTasks < maxConcurrentTasks {
        runningTasks += 1
        return
      }

      await withCheckedContinuation { continuation in
        waitQueue.append(continuation)
      }
      runningTasks += 1
    }

    private func releaseSlot() {
      runningTasks = max(0, runningTasks - 1)
      guard !waitQueue.isEmpty else { return }
      let continuation = waitQueue.removeFirst()
      continuation.resume()
    }

    private func loadModel(descriptor: ReaderUpscaleModelDescriptor) async throws -> (any ReaderImageProcessingModel)? {
      guard let modelURL = resolveModelURL(descriptor: descriptor) else {
        return nil
      }

      let cacheKey = modelURL.path
      if let cached = modelCache[cacheKey] {
        return cached
      }

      let model: MLModel
      if modelURL.pathExtension.lowercased() == "mlmodelc" {
        model = try MLModel(contentsOf: modelURL)
      } else {
        let compiledURL = try await MLModel.compileModel(at: modelURL)
        model = try MLModel(contentsOf: compiledURL)
      }

      let processingModel: (any ReaderImageProcessingModel)?
      switch descriptor.modelType {
      case .multiarray:
        processingModel = ReaderMultiArrayModel(model: model, descriptor: descriptor)
      case .image:
        processingModel = ReaderImageModel(model: model, descriptor: descriptor)
      }

      guard let processingModel else { return nil }
      modelCache[cacheKey] = processingModel
      return processingModel
    }

    private func resolveModelURL(descriptor: ReaderUpscaleModelDescriptor) -> URL? {
      let fileName = descriptor.fileName
      let baseName = (fileName as NSString).deletingPathExtension
      let ext = (fileName as NSString).pathExtension

      if !baseName.isEmpty {
        if !ext.isEmpty {
          if let bundled = bundledResourceURL(resource: baseName, ext: ext) {
            return bundled
          }
        }

        if let compiled = bundledResourceURL(resource: baseName, ext: "mlmodelc") {
          return compiled
        }
      }

      guard let resourceRoot = Bundle.main.resourceURL else { return nil }
      let direct = resourceRoot.appendingPathComponent(fileName)
      if FileManager.default.fileExists(atPath: direct.path) {
        return direct
      }

      return nil
    }

    private func bundledResourceURL(resource: String, ext: String) -> URL? {
      let subdirectories = ["Resources/Upscaling", "Upscaling", "Resources/Models", "Models", nil]
      for subdirectory in subdirectories {
        if let url = Bundle.main.url(forResource: resource, withExtension: ext, subdirectory: subdirectory) {
          return url
        }
      }
      return nil
    }
  }
#endif
