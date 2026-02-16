#if os(iOS) || os(tvOS)
  import Foundation

  nonisolated enum ReaderUpscaleModelType: String, Decodable {
    case multiarray
    case image
  }

  nonisolated struct ReaderUpscaleModelConfig: Decodable {
    let inputName: String?
    let outputName: String?
    let blockSize: Int?
    let shrinkSize: Int?
    let scale: Int?
    let shape: [Int]?
  }

  nonisolated struct ReaderUpscaleModelDescriptor: Decodable {
    let name: String?
    let type: String?
    let file: String
    let config: ReaderUpscaleModelConfig?

    var fileName: String {
      (file as NSString).lastPathComponent
    }

    var modelType: ReaderUpscaleModelType {
      if let type, let parsed = ReaderUpscaleModelType(rawValue: type.lowercased()) {
        return parsed
      }
      return .multiarray
    }

    static let defaultWaifu2x = ReaderUpscaleModelDescriptor(
      name: "waifu2x (photo, 2x, noise0)",
      type: ReaderUpscaleModelType.multiarray.rawValue,
      file: "waifu2x_photo_noise0_scale2x.mlmodel",
      config: ReaderUpscaleModelConfig(
        inputName: "input",
        outputName: "output",
        blockSize: 156,
        shrinkSize: 7,
        scale: 2,
        shape: nil
      )
    )
  }
#endif
