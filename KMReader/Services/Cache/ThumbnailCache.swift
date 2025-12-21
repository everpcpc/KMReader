//
//  ThumbnailCache.swift
//  KMReader
//
//  Created by Komga iOS Client
//

import Foundation
import OSLog

enum ThumbnailType: String, CaseIterable {
  case book
  case series
  case collection
  case readlist
  case page

  nonisolated var pathSegment: String {
    switch self {
    case .book: return "books"
    case .series: return "series"
    case .collection: return "collections"
    case .readlist: return "readlists"
    case .page: return "pages"
    }
  }
}

actor ThumbnailCache {
  static let shared = ThumbnailCache()

  private let logger = AppLogger(.cache)
  private let diskCacheURL: URL = CacheNamespace.directory(for: "KomgaThumbnailCache")
  private let fileManager = FileManager.default
  private var downloadTasks: [String: Task<URL, Error>] = [:]

  // Cached disk cache size (static for shared access)
  private static let cacheSizeActor = CacheSizeActor()

  private static func getMaxDiskCacheSize() -> Int {
    AppConfig.maxThumbnailCacheSize
  }

  private init() {}

  /// Get the local file URL for a thumbnail. The file may or may not exist.
  static nonisolated func getThumbnailFileURL(id: String, type: ThumbnailType, page: Int? = nil)
    -> URL
  {
    let directory = CacheNamespace.directory(for: "KomgaThumbnailCache")
    let typeDir = directory.appendingPathComponent(type.rawValue, isDirectory: true)

    let filename = page != nil ? "\(id)_\(page!).jpg" : "\(id).jpg"
    return typeDir.appendingPathComponent(filename)
  }

  /// Ensures the thumbnail exists locally, downloading it if necessary.
  /// Returns the local file:// URL.
  func ensureThumbnail(id: String, type: ThumbnailType, page: Int? = nil) async throws -> URL {
    let fileURL = Self.getThumbnailFileURL(id: id, type: type, page: page)

    if fileManager.fileExists(atPath: fileURL.path) {
      return fileURL
    }

    let cacheKey = page != nil ? "\(type.rawValue)#\(id)#\(page!)" : "\(type.rawValue)#\(id)"
    if let existingTask = downloadTasks[cacheKey] {
      return try await existingTask.value
    }

    let task = Task<URL, Error> {
      let logSuffix = page != nil ? "page \(page!) of book \(id)" : "\(type.rawValue) \(id)"
      logger.info("📡 Downloading thumbnail for \(logSuffix)")

      // Ensure directory exists
      let typeDir = fileURL.deletingLastPathComponent()
      if !FileManager.default.fileExists(atPath: typeDir.path) {
        try FileManager.default.createDirectory(at: typeDir, withIntermediateDirectories: true)
      }

      let path: String
      if case .page = type, let pageNum = page {
        path = "/api/v1/books/\(id)/pages/\(pageNum)/thumbnail"
      } else {
        path = "/api/v1/\(type.pathSegment)/\(id)/thumbnail"
      }
      let (data, _, _) = try await APIClient.shared.requestData(path: path)

      try data.write(to: fileURL, options: [.atomic])
      logger.info("✅ Saved thumbnail for \(type.rawValue) \(id)")

      // Update cached size and count
      let fileSize = Int64(data.count)
      await Self.cacheSizeActor.updateSize(delta: fileSize)
      await Self.cacheSizeActor.updateCount(delta: 1)

      // Proactively cleanup in background
      Task.detached(priority: .utility) {
        await Self.cleanupDiskCacheIfNeeded()
      }

      return fileURL
    }

    downloadTasks[cacheKey] = task

    do {
      let url = try await task.value
      downloadTasks[cacheKey] = nil
      return url
    } catch {
      downloadTasks[cacheKey] = nil
      logger.error(
        "❌ Failed to download thumbnail for \(type.rawValue) \(id): \(error.localizedDescription)")
      throw error
    }
  }

  // MARK: - Cache Management

  /// Clear all disk cache for thumbnails
  static func clearAllDiskCache() async {
    let fileManager = FileManager.default
    let diskCacheURL = CacheNamespace.baseDirectory(for: "KomgaThumbnailCache")

    await Task.detached(priority: .userInitiated) {
      try? fileManager.removeItem(at: diskCacheURL)
      // Recreate the directory
      try? fileManager.createDirectory(at: diskCacheURL, withIntermediateDirectories: true)
    }.value

    // Reset cached size and count
    await cacheSizeActor.set(size: 0, count: 0)
  }

  /// Get disk cache size in bytes
  static func getDiskCacheSize() async -> Int64 {
    let (size, _, _) = await getDiskCacheInfo()
    return size
  }

  /// Get disk cache file count
  static func getDiskCacheCount() async -> Int {
    let (_, count, _) = await getDiskCacheInfo()
    return count
  }

  /// Cleanup disk cache if needed
  static func cleanupDiskCacheIfNeeded() async {
    let fileManager = FileManager.default
    let diskCacheURL = await namespacedDiskCacheURL()
    let maxCacheSize = getMaxDiskCacheSize()

    await Task.detached(priority: .utility) {
      await performDiskCacheCleanup(
        diskCacheURL: diskCacheURL,
        fileManager: fileManager,
        maxCacheSize: maxCacheSize
      )
    }.value
  }

  // MARK: - Private Management Helpers

  private static func getDiskCacheInfo() async -> (size: Int64, count: Int, isValid: Bool) {
    let cacheInfo = await cacheSizeActor.get()
    if cacheInfo.isValid, let size = cacheInfo.size, let count = cacheInfo.count {
      return (size, count, true)
    }

    let fileManager = FileManager.default
    let diskCacheURL = await namespacedDiskCacheURL()

    let result: (size: Int64, count: Int) = await Task.detached(priority: .utility) {
      guard fileManager.fileExists(atPath: diskCacheURL.path) else {
        return (0, 0)
      }

      let (_, fileInfo, totalSize) = collectFileInfo(
        at: diskCacheURL,
        fileManager: fileManager,
        includeDate: false
      )

      return (totalSize, fileInfo.count)
    }.value

    await cacheSizeActor.set(size: result.size, count: result.count)
    return (result.size, result.count, true)
  }

  nonisolated private static func namespacedDiskCacheURL() async -> URL {
    await MainActor.run {
      CacheNamespace.directory(for: "KomgaThumbnailCache")
    }
  }

  private static func collectFiles(at url: URL, fileManager: FileManager) -> [URL] {
    var files: [URL] = []
    guard
      let contents = try? fileManager.contentsOfDirectory(
        at: url,
        includingPropertiesForKeys: [.isDirectoryKey],
        options: [.skipsHiddenFiles]
      )
    else {
      return files
    }

    for item in contents {
      if let isDirectory = try? item.resourceValues(forKeys: [.isDirectoryKey]).isDirectory,
        isDirectory == true
      {
        files.append(contentsOf: collectFiles(at: item, fileManager: fileManager))
      } else {
        files.append(item)
      }
    }
    return files
  }

  private static func collectFileInfo(
    at diskCacheURL: URL,
    fileManager: FileManager,
    includeDate: Bool = false
  ) -> (files: [URL], fileInfo: [(url: URL, size: Int64, date: Date?)], totalSize: Int64) {
    let allFiles = collectFiles(at: diskCacheURL, fileManager: fileManager)
    var totalSize: Int64 = 0
    var fileInfo: [(url: URL, size: Int64, date: Date?)] = []

    let keys: Set<URLResourceKey> =
      includeDate
      ? [.fileSizeKey, .contentModificationDateKey]
      : [.fileSizeKey]

    for fileURL in allFiles {
      if let resourceValues = try? fileURL.resourceValues(forKeys: keys),
        let size = resourceValues.fileSize
      {
        totalSize += Int64(size)
        fileInfo.append(
          (url: fileURL, size: Int64(size), date: resourceValues.contentModificationDate))
      }
    }

    return (allFiles, fileInfo, totalSize)
  }

  private static func performDiskCacheCleanup(
    diskCacheURL: URL,
    fileManager: FileManager,
    maxCacheSize: Int
  ) async {
    let maxSize = Int64(maxCacheSize) * 1024 * 1024 * 1024
    let (_, fileInfo, totalSize) = collectFileInfo(
      at: diskCacheURL,
      fileManager: fileManager,
      includeDate: true
    )

    if totalSize > maxSize {
      let oldestFirst = fileInfo.sorted {
        ($0.date ?? Date.distantPast) < ($1.date ?? Date.distantPast)
      }
      var currentSize = totalSize
      for info in oldestFirst {
        if currentSize <= maxSize { break }
        try? fileManager.removeItem(at: info.url)
        currentSize -= info.size
      }
      await cacheSizeActor.invalidate()
    } else {
      await cacheSizeActor.set(size: totalSize, count: fileInfo.count)
    }
  }
}
