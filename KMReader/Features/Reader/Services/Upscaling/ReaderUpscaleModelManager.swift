#if os(iOS) || os(tvOS)
  import CoreML
  import Foundation

  actor ReaderUpscaleModelManager {
    static let shared = ReaderUpscaleModelManager()

    private var modelCache: [String: any ReaderImageProcessingModel] = [:]
    private var preferredDescriptor: ReaderUpscaleModelDescriptor?
    private var hasLoggedMissingDescriptor = false
    private let logger = AppLogger(.reader)
    private let maxConcurrentTasks = 2
    private var runningTasks = 0
    private var waitQueue: [CheckedContinuation<Void, Never>] = []

    func process(_ image: CGImage) async -> CGImage? {
      guard !Task.isCancelled else { return nil }
      guard let descriptor = resolveDefaultDescriptor() else {
        if !hasLoggedMissingDescriptor {
          logger.debug("⏭️ [Upscale] No available model descriptor from models.json/defaults")
          hasLoggedMissingDescriptor = true
        }
        return nil
      }
      hasLoggedMissingDescriptor = false

      let model: (any ReaderImageProcessingModel)
      do {
        guard let loadedModel = try await loadModel(descriptor: descriptor) else {
          logger.debug("⏭️ [Upscale] Skip processing because model file is unavailable: \(descriptor.file)")
          return nil
        }
        model = loadedModel
      } catch {
        logger.error("[Upscale] Failed to load model \(descriptor.file): \(error.localizedDescription)")
        return nil
      }

      guard !Task.isCancelled else { return nil }
      await acquireSlot()
      defer { releaseSlot() }

      guard !Task.isCancelled else { return nil }
      return await model.process(image)
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

    private func resolveDefaultDescriptor() -> ReaderUpscaleModelDescriptor? {
      if let preferredDescriptor, resolveModelURL(descriptor: preferredDescriptor) != nil {
        return preferredDescriptor
      }

      let descriptors = loadModelList()
      let available = descriptors.filter { resolveModelURL(descriptor: $0) != nil }

      let resolved: ReaderUpscaleModelDescriptor?
      if let preferred = available.first(where: { $0.fileName == ReaderUpscaleModelDescriptor.defaultWaifu2x.fileName }) {
        resolved = preferred
      } else if let first = available.first {
        resolved = first
      } else if resolveModelURL(descriptor: ReaderUpscaleModelDescriptor.defaultWaifu2x) != nil {
        resolved = ReaderUpscaleModelDescriptor.defaultWaifu2x
      } else if resolveModelURL(descriptor: ReaderUpscaleModelDescriptor.defaultRealESRGAN) != nil {
        resolved = ReaderUpscaleModelDescriptor.defaultRealESRGAN
      } else {
        resolved = nil
      }

      if preferredDescriptor?.file != resolved?.file {
        if let resolved {
          logger.debug("[Upscale] Using model descriptor: \(resolved.file) (type=\(resolved.modelType.rawValue))")
        }
      }

      preferredDescriptor = resolved
      return resolved
    }

    private func loadModel(descriptor: ReaderUpscaleModelDescriptor) async throws -> (any ReaderImageProcessingModel)? {
      guard let modelURL = resolveModelURL(descriptor: descriptor) else {
        return nil
      }

      let cacheKey = modelURL.path
      if let cached = modelCache[cacheKey] {
        return cached
      }

      logger.debug("[Upscale] Loading model from \(modelURL.lastPathComponent)")
      let compiledURL = try await MLModel.compileModel(at: modelURL)
      let model = try MLModel(contentsOf: compiledURL)

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

    private func loadModelList() -> [ReaderUpscaleModelDescriptor] {
      guard let listURL = resolveModelsListURL() else {
        return [
          ReaderUpscaleModelDescriptor.defaultWaifu2x,
          ReaderUpscaleModelDescriptor.defaultRealESRGAN,
        ]
      }

      guard
        let data = try? Data(contentsOf: listURL),
        let list = try? JSONDecoder().decode(ReaderUpscaleModelList.self, from: data)
      else {
        return [
          ReaderUpscaleModelDescriptor.defaultWaifu2x,
          ReaderUpscaleModelDescriptor.defaultRealESRGAN,
        ]
      }

      return list.models
    }

    private func resolveModelsListURL() -> URL? {
      let fm = FileManager.default
      let appSupportDir = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
      let documentsDir = fm.urls(for: .documentDirectory, in: .userDomainMask).first

      return [appSupportDir, documentsDir]
        .compactMap { $0?.appendingPathComponent("Models").appendingPathComponent("models.json") }
        .first(where: { fm.fileExists(atPath: $0.path) })
    }

    private func resolveModelURL(descriptor: ReaderUpscaleModelDescriptor) -> URL? {
      if let modelURL = resolveModelURL(path: descriptor.file) {
        return modelURL
      }
      if descriptor.fileName != descriptor.file {
        return resolveModelURL(path: descriptor.fileName)
      }
      return nil
    }

    private func resolveModelURL(path: String) -> URL? {
      let normalizedPath = path.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !normalizedPath.isEmpty else { return nil }

      let fm = FileManager.default
      let expandedPath = (normalizedPath as NSString).expandingTildeInPath
      if normalizedPath.hasPrefix("/") || normalizedPath.hasPrefix("~") {
        let absoluteURL = URL(fileURLWithPath: expandedPath)
        if fm.fileExists(atPath: absoluteURL.path) {
          return absoluteURL
        }
      }

      let relativePath = normalizedPath.hasPrefix("./") ? String(normalizedPath.dropFirst(2)) : normalizedPath
      let candidatePaths = [relativePath, (relativePath as NSString).lastPathComponent]

      let appSupportDir = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
      let documentsDir = fm.urls(for: .documentDirectory, in: .userDomainMask).first
      let roots = [appSupportDir, documentsDir]

      for candidatePath in candidatePaths where !candidatePath.isEmpty {
        for root in roots {
          guard let root else { continue }
          let modelURL = root
            .appendingPathComponent("Models")
            .appendingPathComponent(candidatePath)
          if fm.fileExists(atPath: modelURL.path) {
            return modelURL
          }
        }
      }

      return nil
    }
  }
#endif
