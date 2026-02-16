#if os(iOS) || os(tvOS)
  import CoreML
  import Foundation

  actor ReaderUpscaleModelManager {
    static let shared = ReaderUpscaleModelManager()

    private static let remoteModelListURL = URL(string: "https://upscale.aidoku.app/models.json")!
    private static let bootstrapCooldown: TimeInterval = 300

    private var modelCache: [String: any ReaderImageProcessingModel] = [:]
    private var preferredDescriptor: ReaderUpscaleModelDescriptor?
    private var hasLoggedMissingDescriptor = false
    private let logger = AppLogger(.reader)
    private let maxConcurrentTasks = 2
    private var runningTasks = 0
    private var waitQueue: [CheckedContinuation<Void, Never>] = []

    private var isBootstrapping = false
    private var lastBootstrapAttemptAt: Date?

    func activeDescriptor() -> ReaderUpscaleModelDescriptor? {
      resolveDefaultDescriptor()
    }

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
      let output = await model.process(image)
      if output == nil {
        logger.debug("⏭️ [Upscale] Model returned nil output: \(descriptor.file)")
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

      if resolved == nil {
        scheduleBootstrapIfNeeded()
      }

      return resolved
    }

    private func scheduleBootstrapIfNeeded() {
      if isBootstrapping {
        return
      }

      if let lastBootstrapAttemptAt,
        Date().timeIntervalSince(lastBootstrapAttemptAt) < Self.bootstrapCooldown
      {
        return
      }

      isBootstrapping = true
      lastBootstrapAttemptAt = Date()

      Task {
        await bootstrapDefaultModelIfNeeded()
      }
    }

    private func bootstrapDefaultModelIfNeeded() async {
      defer { isBootstrapping = false }

      do {
        let modelsDir = try modelsDirectory()
        let (modelList, rawData) = try await fetchRemoteModelList()
        try rawData.write(to: modelsDir.appendingPathComponent("models.json"), options: .atomic)

        guard let descriptor = selectBootstrapDescriptor(from: modelList.models) else {
          logger.debug("⏭️ [Upscale] No downloadable default model from remote list")
          return
        }

        if resolveModelURL(descriptor: descriptor) != nil {
          logger.debug("[Upscale] Default model already available: \(descriptor.fileName)")
          return
        }

        try await downloadModelIfNeeded(descriptor: descriptor, modelsDir: modelsDir)
        preferredDescriptor = nil
      } catch {
        logger.error("[Upscale] Bootstrap download failed: \(error.localizedDescription)")
      }
    }

    private func fetchRemoteModelList() async throws -> (ReaderUpscaleModelList, Data) {
      let (data, response) = try await URLSession.shared.data(from: Self.remoteModelListURL)
      if let http = response as? HTTPURLResponse,
        !(200..<300).contains(http.statusCode)
      {
        throw NSError(
          domain: "ReaderUpscaleModelManager",
          code: http.statusCode,
          userInfo: [NSLocalizedDescriptionKey: "unexpected status code \(http.statusCode)"]
        )
      }

      let list = try JSONDecoder().decode(ReaderUpscaleModelList.self, from: data)
      return (list, data)
    }

    private func selectBootstrapDescriptor(from models: [ReaderUpscaleModelDescriptor]) -> ReaderUpscaleModelDescriptor? {
      if let preferred = models.first(where: { $0.fileName == ReaderUpscaleModelDescriptor.defaultWaifu2x.fileName }) {
        return preferred
      }

      return models.first(where: { $0.fileName.lowercased().hasSuffix(".mlmodel") })
    }

    private func downloadModelIfNeeded(
      descriptor: ReaderUpscaleModelDescriptor,
      modelsDir: URL
    ) async throws {
      guard descriptor.fileName.lowercased().hasSuffix(".mlmodel") else {
        logger.debug("⏭️ [Upscale] Auto download skips unsupported package type: \(descriptor.file)")
        return
      }

      let destinationURL = modelsDir.appendingPathComponent(descriptor.fileName)
      if FileManager.default.fileExists(atPath: destinationURL.path) {
        return
      }

      guard let remoteURL = URL(string: descriptor.file, relativeTo: Self.remoteModelListURL) else {
        throw NSError(
          domain: "ReaderUpscaleModelManager",
          code: -1,
          userInfo: [NSLocalizedDescriptionKey: "invalid remote model path: \(descriptor.file)"]
        )
      }

      logger.info("[Upscale] Downloading default model: \(descriptor.file)")
      let (data, response) = try await URLSession.shared.data(from: remoteURL)
      if let http = response as? HTTPURLResponse,
        !(200..<300).contains(http.statusCode)
      {
        throw NSError(
          domain: "ReaderUpscaleModelManager",
          code: http.statusCode,
          userInfo: [NSLocalizedDescriptionKey: "model download status \(http.statusCode)"]
        )
      }

      let temporaryURL = modelsDir.appendingPathComponent("\(descriptor.fileName).download")
      try data.write(to: temporaryURL, options: .atomic)
      if FileManager.default.fileExists(atPath: destinationURL.path) {
        try FileManager.default.removeItem(at: destinationURL)
      }
      try FileManager.default.moveItem(at: temporaryURL, to: destinationURL)
      try markExcludedFromBackup(destinationURL)
      logger.info("[Upscale] Downloaded default model to Application Support: \(destinationURL.lastPathComponent)")
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

    private func modelsDirectory() throws -> URL {
      guard let appSupportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
        throw NSError(
          domain: "ReaderUpscaleModelManager",
          code: -1,
          userInfo: [NSLocalizedDescriptionKey: "unable to resolve Application Support directory"]
        )
      }

      let modelsDir = appSupportDir.appendingPathComponent("Models", isDirectory: true)
      if !FileManager.default.fileExists(atPath: modelsDir.path) {
        try FileManager.default.createDirectory(at: modelsDir, withIntermediateDirectories: true)
      }
      try markExcludedFromBackup(modelsDir)
      return modelsDir
    }

    private func markExcludedFromBackup(_ url: URL) throws {
      var mutableURL = url
      var values = URLResourceValues()
      values.isExcludedFromBackup = true
      try mutableURL.setResourceValues(values)
    }

    private func resolveModelsListURL() -> URL? {
      guard let modelsDir = try? modelsDirectory() else { return nil }

      let listURL = modelsDir.appendingPathComponent("models.json")
      return FileManager.default.fileExists(atPath: listURL.path) ? listURL : nil
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

      guard let modelsDir = try? modelsDirectory() else { return nil }

      let relativePath = normalizedPath.hasPrefix("./") ? String(normalizedPath.dropFirst(2)) : normalizedPath
      let candidatePaths = [relativePath, (relativePath as NSString).lastPathComponent]

      for candidatePath in candidatePaths where !candidatePath.isEmpty {
        let modelURL = modelsDir.appendingPathComponent(candidatePath)
        if fm.fileExists(atPath: modelURL.path) {
          return modelURL
        }
      }

      return nil
    }
  }
#endif
