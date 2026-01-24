//
//  Book+Download.swift
//  KMReader
//
//  Created by Komga iOS Client
//

import Foundation
import UniformTypeIdentifiers

extension Book {
  var downloadFileName: String {
    let baseName = metadata.title.isEmpty ? name : metadata.title
    let fallback = "book-\(id.prefix(8))"
    let resolvedBase = baseName.isEmpty ? fallback : baseName

    let extensionPart = downloadFileExtension ?? ""
    let combinedName =
      extensionPart.isEmpty ? resolvedBase : "\(resolvedBase).\(extensionPart.lowercased())"

    return FileNameHelper.sanitizedFileName(combinedName, defaultBaseName: fallback)
  }

  var downloadUTType: UTType? {
    guard let mimeType = normalizedMediaType else { return nil }
    return UTType(mimeType: mimeType)
  }

  private var downloadFileExtension: String? {
    if let urlExtension = URL(string: url)?.pathExtension, !urlExtension.isEmpty {
      return urlExtension
    }

    if let utType = downloadUTType,
      let ext = utType.preferredFilenameExtension
    {
      return ext
    }

    return nil
  }

  private var normalizedMediaType: String? {
    guard !media.mediaType.isEmpty else { return nil }
    return media.mediaType.split(separator: ";").first?.trimmingCharacters(in: .whitespaces)
  }

  var isDivina: Bool {
    guard let mediaProfile = media.mediaProfile else { return true }
    return mediaProfile != .epub
  }
}
