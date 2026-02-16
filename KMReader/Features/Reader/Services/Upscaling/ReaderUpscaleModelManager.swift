#if os(iOS) || os(tvOS)
  import CoreImage
  import CoreML
  import Foundation
  @preconcurrency import Vision

  actor ReaderUpscaleModelManager {
    static let shared = ReaderUpscaleModelManager()

    private var modelCache: [String: VNCoreMLModel] = [:]

    func process(_ image: CGImage) async -> CGImage? {
      guard !Task.isCancelled else { return nil }
      guard let model = try? await loadEnabledModel() else { return nil }
      guard !Task.isCancelled else { return nil }

      let request = VNCoreMLRequest(model: model)
      request.imageCropAndScaleOption = .scaleFill
      let handler = VNImageRequestHandler(cgImage: image, options: [:])
      try? handler.perform([request])

      guard !Task.isCancelled else { return nil }
      guard let result = request.results?.first as? VNPixelBufferObservation else { return nil }
      return CIImage(cvImageBuffer: result.pixelBuffer).cgImage
    }

    private func loadEnabledModel() async throws -> VNCoreMLModel? {
      guard let fileName = AppConfig.enabledImageUpscaleModelFile, !fileName.isEmpty else {
        return nil
      }

      if let cached = modelCache[fileName] {
        return cached
      }

      guard let modelURL = resolveModelURL(fileName: fileName) else {
        return nil
      }

      let compiledURL = try await MLModel.compileModel(at: modelURL)
      let model = try MLModel(contentsOf: compiledURL)
      guard let vnModel = try? VNCoreMLModel(for: model) else {
        return nil
      }

      modelCache[fileName] = vnModel
      return vnModel
    }

    private func resolveModelURL(fileName: String) -> URL? {
      let fm = FileManager.default
      let appSupportDir = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
      let documentsDir = fm.urls(for: .documentDirectory, in: .userDomainMask).first

      return [appSupportDir, documentsDir]
        .compactMap { $0?.appendingPathComponent("Models").appendingPathComponent(fileName) }
        .first(where: { fm.fileExists(atPath: $0.path) })
    }
  }
#endif
