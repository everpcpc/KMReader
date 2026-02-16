#if os(iOS) || os(tvOS)
  import CoreImage
  import CoreML
  import Foundation
  @preconcurrency import Vision

  nonisolated final class ReaderImageModel: ReaderImageProcessingModel {
    private let vnModel: VNCoreMLModel

    nonisolated required init?(model: MLModel, descriptor _: ReaderUpscaleModelDescriptor) {
      guard let vnModel = try? VNCoreMLModel(for: model) else {
        return nil
      }
      self.vnModel = vnModel
    }

    nonisolated func process(_ image: CGImage) async -> CGImage? {
      await withCheckedContinuation { continuation in
        DispatchQueue.global(qos: .userInitiated).async { [vnModel] in
          let request = VNCoreMLRequest(model: vnModel)
          request.imageCropAndScaleOption = .scaleFill
          let handler = VNImageRequestHandler(cgImage: image, options: [:])
          try? handler.perform([request])

          guard let result = request.results?.first as? VNPixelBufferObservation else {
            continuation.resume(returning: nil)
            return
          }

          let output = CIImage(cvImageBuffer: result.pixelBuffer).cgImage
          continuation.resume(returning: output)
        }
      }
    }
  }
#endif
