//
// BookPage.swift
//
//

import Foundation
import UniformTypeIdentifiers

struct BookPage: Codable, Identifiable, Sendable {
  let number: Int
  let fileName: String
  let mediaType: String
  let width: Int?
  let height: Int?
  let sizeBytes: Int64?
  let size: String
  let downloadURL: URL?

  var id: Int { number }
}

extension BookPage {
  nonisolated var hasValidDimensions: Bool {
    guard let width, let height else { return false }
    return width > 0 && height > 0
  }

  nonisolated var isAnimatedImageCandidate: Bool {
    let fileExtension = (fileName as NSString).pathExtension.lowercased()
    if fileExtension == "gif" || fileExtension == "webp" {
      return true
    }

    let mimeType =
      mediaType.split(separator: ";").first?.trimmingCharacters(in: .whitespaces)
      ?? mediaType
    return mimeType == "image/gif" || mimeType == "image/webp"
  }

  /// Best-effort UTType detection using file extension first, then MIME type.
  nonisolated var detectedUTType: UTType? {
    let fileExtension = (fileName as NSString).pathExtension.lowercased()
    if !fileExtension.isEmpty, let type = UTType(filenameExtension: fileExtension) {
      return type
    }

    let mimeType =
      mediaType.split(separator: ";").first?.trimmingCharacters(in: .whitespaces)
      ?? mediaType
    return UTType(mimeType: mimeType)
  }

  var isPortrait: Bool {
    guard let width = width, let height = height else { return false }
    return height > width
  }

  func withDownloadURL(_ url: URL?) -> BookPage {
    BookPage(
      number: number,
      fileName: fileName,
      mediaType: mediaType,
      width: width,
      height: height,
      sizeBytes: sizeBytes,
      size: size,
      downloadURL: url
    )
  }

  nonisolated func withDimensions(width: Int, height: Int) -> BookPage {
    BookPage(
      number: number,
      fileName: fileName,
      mediaType: mediaType,
      width: self.width.flatMap { $0 > 0 ? $0 : nil } ?? width,
      height: self.height.flatMap { $0 > 0 ? $0 : nil } ?? height,
      sizeBytes: sizeBytes,
      size: size,
      downloadURL: downloadURL
    )
  }
}
