//
//  ImageSaveHelper.swift
//  KMReader
//
//  Helper for saving images to Photos library
//

import Photos
import SwiftUI
import UniformTypeIdentifiers

enum ImageSaveHelper {
  static func saveToPhotos(image: PlatformImage) {
    Task {
      let result = await performSave(image: image)
      switch result {
      case .success:
        ErrorManager.shared.notify(message: String(localized: "notification.reader.imageSaved"))
      case .failure(let error):
        ErrorManager.shared.alert(error: error)
      }
    }
  }

  private static func performSave(image: PlatformImage) async -> Result<Void, AppErrorType> {
    // Check photo library authorization
    let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
    guard status == .authorized || status == .limited else {
      return .failure(.photoLibraryAccessDenied)
    }

    // Try to get PNG data from the image
    guard let pngData = PlatformHelper.pngData(from: image) else {
      return .failure(.failedToLoadImageData)
    }

    do {
      try await PHPhotoLibrary.shared().performChanges {
        let creationRequest = PHAssetCreationRequest.forAsset()
        let options = PHAssetResourceCreationOptions()
        options.uniformTypeIdentifier = UTType.png.identifier
        creationRequest.addResource(with: .photo, data: pngData, options: options)
      }
      return .success(())
    } catch {
      return .failure(.saveImageError(error.localizedDescription))
    }
  }
}
