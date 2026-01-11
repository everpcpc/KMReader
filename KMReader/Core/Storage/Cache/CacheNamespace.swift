//
//  CacheNamespace.swift
//  KMReader
//
//  Created by Komga iOS Client
//

import Foundation

/// Provides a per-instance namespace for cache folders so multiple servers don't share disk state.
enum CacheNamespace {
  /// Returns the active Komga instance identifier for namespace segregation.
  static nonisolated func identifier() -> String {
    let instanceId = AppConfig.current.instanceId
    guard !instanceId.isEmpty else {
      return "default"
    }
    return sanitize(instanceId)
  }

  /// Namespace-aware cache directory for the given cache name.
  static nonisolated func directory(for cacheName: String) -> URL {
    directory(for: cacheName, instanceId: identifier())
  }

  /// Namespace-aware cache directory for a specific Komga instance.
  static nonisolated func directory(for cacheName: String, instanceId: String) -> URL {
    let sanitizedId = sanitize(instanceId)
    let base = baseDirectory(for: cacheName)
    let url = base.appendingPathComponent(sanitizedId, isDirectory: true)
    ensureDirectoryExists(at: url)
    return url
  }

  /// Root directory shared by all namespaces for the cache.
  nonisolated static func baseDirectory(for cacheName: String) -> URL {
    let cachesDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
    let base = cachesDir.appendingPathComponent(cacheName, isDirectory: true)
    ensureDirectoryExists(at: base)
    return base
  }

  /// Removes the namespace directory for the given cache and instance id.
  nonisolated static func removeNamespace(for cacheName: String, instanceId: String) {
    let sanitizedId = sanitize(instanceId)
    let url = baseDirectory(for: cacheName).appendingPathComponent(sanitizedId, isDirectory: true)
    try? FileManager.default.removeItem(at: url)
  }

  // MARK: - Helpers

  nonisolated private static func ensureDirectoryExists(at url: URL) {
    var isDirectory: ObjCBool = false
    if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
      isDirectory.boolValue
    {
      return
    }
    try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
  }

  nonisolated private static func sanitize(_ value: String) -> String {
    let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-._"))
    let sanitized = value.reduce(into: "") { partialResult, character in
      if character.unicodeScalars.allSatisfy({ allowed.contains($0) }) {
        partialResult.append(character)
      } else {
        partialResult.append("-")
      }
    }
    let trimmed = sanitized.trimmingCharacters(in: CharacterSet(charactersIn: "-._"))
    if trimmed.isEmpty {
      return "default"
    }
    let maxLength = 60
    if trimmed.count > maxLength {
      let endIndex = trimmed.index(trimmed.startIndex, offsetBy: maxLength)
      return String(trimmed[..<endIndex])
    }
    return trimmed
  }
}
