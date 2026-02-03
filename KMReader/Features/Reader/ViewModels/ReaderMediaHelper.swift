//
//  ReaderMediaHelper.swift
//  KMReader
//
//  Created by Komga iOS Client
//

import Foundation
import UniformTypeIdentifiers

enum ReaderMediaHelper {
  static nonisolated func normalizedMimeType(_ original: String?) -> String {
    guard
      let original = original,
      !original.isEmpty
    else { return "" }
    let base = original.split(separator: ";", maxSplits: 1, omittingEmptySubsequences: true).first
    return base?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
  }

  static nonisolated func guessMediaType(for url: URL, fallback: String? = nil) -> String {
    let fileExtension = url.pathExtension.lowercased()
    if !fileExtension.isEmpty,
      let type = UTType(filenameExtension: fileExtension),
      let mime = type.preferredMIMEType
    {
      return mime
    }

    if let fallback = fallback, !fallback.isEmpty {
      return fallback
    }

    return "image/jpeg"
  }
}
