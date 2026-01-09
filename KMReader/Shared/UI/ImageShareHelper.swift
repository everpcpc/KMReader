//
//  ImageShareHelper.swift
//  KMReader
//
//  Helper for sharing images with proper preview support
//

import SwiftUI

#if os(iOS)
  import LinkPresentation
  import UIKit

  // Custom activity item source to provide image preview in share sheet
  final class ImageActivityItemSource: NSObject, UIActivityItemSource {
    let image: UIImage
    let fileName: String?

    init(image: UIImage, fileName: String? = nil) {
      self.image = image
      self.fileName = fileName
      super.init()
    }

    func activityViewControllerPlaceholderItem(
      _ activityViewController: UIActivityViewController
    ) -> Any {
      return image
    }

    func activityViewController(
      _ activityViewController: UIActivityViewController,
      itemForActivityType activityType: UIActivity.ActivityType?
    ) -> Any? {
      return image
    }

    func activityViewControllerLinkMetadata(
      _ activityViewController: UIActivityViewController
    ) -> LPLinkMetadata? {
      let metadata = LPLinkMetadata()
      // Extract basename from fileName (may contain directory path)
      let displayName = fileName.map { ($0 as NSString).lastPathComponent } ?? String(localized: "Image")
      metadata.title = displayName
      metadata.imageProvider = NSItemProvider(object: image)
      return metadata
    }
  }

  enum ImageShareHelper {
    static func share(image: UIImage, fileName: String? = nil) {
      // Get the key window's root view controller to present from
      guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
        let rootVC = windowScene.windows.first?.rootViewController
      else { return }

      // Find the topmost presented view controller
      var topVC = rootVC
      while let presented = topVC.presentedViewController {
        topVC = presented
      }

      // Extract basename from fileName (may contain directory path)
      let baseName = fileName.map { ($0 as NSString).lastPathComponent }

      // Use custom activity item source to provide image preview
      let itemSource = ImageActivityItemSource(image: image, fileName: baseName)
      let activityVC = UIActivityViewController(
        activityItems: [itemSource], applicationActivities: nil)

      // For iPad: set source view to avoid crash
      if let popover = activityVC.popoverPresentationController {
        popover.sourceView = topVC.view
        popover.sourceRect = CGRect(
          x: topVC.view.bounds.midX, y: topVC.view.bounds.midY, width: 0, height: 0)
        popover.permittedArrowDirections = []
      }

      topVC.present(activityVC, animated: true)
    }
  }

#elseif os(macOS)
  import AppKit

  enum ImageShareHelper {
    static func share(image: NSImage, fileName: String? = nil) {
      guard let contentView = NSApp.keyWindow?.contentView else { return }

      // Create a temporary file for sharing with proper preview
      let tempURL = createTempImageFile(image: image, fileName: fileName)
      let sharingItem: Any = tempURL ?? image

      let picker = NSSharingServicePicker(items: [sharingItem])

      // Show picker at center of window
      let rect = CGRect(
        x: contentView.bounds.midX,
        y: contentView.bounds.midY,
        width: 1,
        height: 1
      )
      picker.show(relativeTo: rect, of: contentView, preferredEdge: .minY)
    }

    private static func createTempImageFile(image: NSImage, fileName: String?) -> URL? {
      // Extract basename from fileName (may contain directory path) and determine extension
      let baseName = fileName.map { ($0 as NSString).lastPathComponent } ?? "SharedImage"
      let nameWithoutExt = (baseName as NSString).deletingPathExtension
      let originalExt = (baseName as NSString).pathExtension.lowercased()

      // Use original extension if it's a supported image type, otherwise use PNG
      let fileExtension = ["jpg", "jpeg", "png", "heic", "heif", "gif", "webp"].contains(originalExt)
        ? originalExt : "png"

      let tempDir = FileManager.default.temporaryDirectory
      let tempURL = tempDir.appendingPathComponent("\(nameWithoutExt).\(fileExtension)")

      // Remove existing file if any
      try? FileManager.default.removeItem(at: tempURL)

      // Convert NSImage to appropriate data format
      guard let tiffData = image.tiffRepresentation,
        let bitmapRep = NSBitmapImageRep(data: tiffData)
      else {
        return nil
      }

      let imageData: Data?
      if fileExtension == "jpg" || fileExtension == "jpeg" {
        imageData = bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: 0.9])
      } else {
        imageData = bitmapRep.representation(using: .png, properties: [:])
      }

      guard let data = imageData else { return nil }

      do {
        try data.write(to: tempURL)
        return tempURL
      } catch {
        return nil
      }
    }
  }
#endif
