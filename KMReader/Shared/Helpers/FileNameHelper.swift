//
//  FileNameHelper.swift
//  KMReader
//
//  Created by Komga iOS Client
//

import Foundation

enum FileNameHelper {
  nonisolated static func sanitizedFileName(_ originalName: String, defaultBaseName: String)
    -> String
  {
    let nsName = originalName as NSString
    let ext = nsName.pathExtension
    let base = nsName.deletingPathExtension

    let sanitizedBase = sanitizeComponent(base, fallback: defaultBaseName)
    let sanitizedExtension = sanitizeExtension(ext)

    guard !sanitizedExtension.isEmpty else {
      return sanitizedBase
    }

    return "\(sanitizedBase).\(sanitizedExtension)"
  }

  nonisolated private static func sanitizeComponent(_ value: String, fallback: String) -> String {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    let invalidCharacters = CharacterSet(charactersIn: "\\/:*?\"<>|")

    var sanitized = trimmed.components(separatedBy: invalidCharacters).joined(separator: "-")
    sanitized = sanitized.replacingOccurrences(of: " ", with: "-")

    while sanitized.contains("--") {
      sanitized = sanitized.replacingOccurrences(of: "--", with: "-")
    }

    if sanitized.isEmpty {
      return fallback
    }

    return sanitized
  }

  nonisolated private static func sanitizeExtension(_ value: String) -> String {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    let allowedCharacters = CharacterSet.alphanumerics
    let filtered = trimmed.unicodeScalars.filter { allowedCharacters.contains($0) }
    return String(filtered).lowercased()
  }
}
