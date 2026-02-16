#if os(iOS) || os(tvOS)
  import CoreGraphics
  import CoreML

  protocol ReaderImageProcessingModel {
    nonisolated init?(model: MLModel, descriptor: ReaderUpscaleModelDescriptor)
    nonisolated func process(_ image: CGImage) async -> CGImage?
  }
#endif
