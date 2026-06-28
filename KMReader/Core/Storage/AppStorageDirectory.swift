//
// AppStorageDirectory.swift
//
//

import Foundation

nonisolated enum AppStorageDirectory {
  #if os(tvOS)
    private static let tvOSSupportFallbackName = "KMReaderSupport"
    private static let libraryCachesPath = "Library/Caches"
  #endif

  static func supportDirectory(fileManager: FileManager = .default) throws -> URL {
    #if os(tvOS)
      return try tvOSSupportDirectory(fileManager: fileManager)
    #else
      return try standardApplicationSupport(fileManager: fileManager)
    #endif
  }

  static func supportDirectoryCandidates(fileManager: FileManager = .default) -> [URL] {
    var candidates: [URL] = []

    #if os(tvOS)
      if let support = tvOSSupportDirectoryCandidate(fileManager: fileManager) {
        candidates.append(support)
      }
      if let appContainerSupport = tvOSAppContainerSupportDirectoryCandidate(fileManager: fileManager) {
        candidates.append(appContainerSupport)
      }
      if let sharedCaches = sharedContainerCachesDirectoryCandidate() {
        candidates.append(sharedCaches)
      }
    #endif

    if let applicationSupport = applicationSupportCandidate(fileManager: fileManager) {
      candidates.append(applicationSupport)
    }

    return uniquedByPath(candidates)
  }

  static func ensureDirectoryExists(at url: URL, fileManager: FileManager = .default) throws {
    var isDirectory: ObjCBool = false
    if fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory),
      isDirectory.boolValue
    {
      return
    }
    try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
  }

  private static func standardApplicationSupport(fileManager: FileManager) throws -> URL {
    let unavailableError = AppErrorType.storageNotConfigured(message: "Application Support directory is unavailable")
    guard let applicationSupport = applicationSupportCandidate(fileManager: fileManager) else {
      throw unavailableError
    }

    try ensureDirectoryExists(at: applicationSupport, fileManager: fileManager)
    return applicationSupport
  }

  private static func applicationSupportCandidate(fileManager: FileManager) -> URL? {
    fileManager.urls(
      for: .applicationSupportDirectory,
      in: .userDomainMask
    ).first
  }

  private static func uniquedByPath(_ urls: [URL]) -> [URL] {
    var seen = Set<String>()
    var result: [URL] = []
    for url in urls {
      let path = url.standardizedFileURL.path
      guard seen.insert(path).inserted else { continue }
      result.append(url)
    }
    return result
  }

  #if os(tvOS)
    private static func tvOSSupportDirectory(fileManager: FileManager) throws -> URL {
      guard let support = tvOSSupportDirectoryCandidate(fileManager: fileManager) else {
        throw AppErrorType.storageNotConfigured(message: "tvOS cache directory is unavailable")
      }

      try ensureDirectoryExists(at: support, fileManager: fileManager)
      return support
    }

    private static func tvOSSupportDirectoryCandidate(fileManager: FileManager) -> URL? {
      tvOSAppContainerSupportDirectoryCandidate(fileManager: fileManager)
    }

    private static func tvOSAppContainerSupportDirectoryCandidate(fileManager: FileManager) -> URL? {
      guard
        let caches = fileManager.urls(
          for: .cachesDirectory,
          in: .userDomainMask
        ).first
      else {
        return nil
      }

      return caches.appendingPathComponent(tvOSSupportFallbackName, isDirectory: true)
    }

    private static func sharedContainerCachesDirectoryCandidate() -> URL? {
      WidgetDataStore.sharedContainerURL?.appendingPathComponent(libraryCachesPath, isDirectory: true)
    }
  #endif
}
