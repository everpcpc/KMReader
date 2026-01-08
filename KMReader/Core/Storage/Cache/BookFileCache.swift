//
//  BookFileCache.swift
//  KMReader
//
//  Created by Komga iOS Client
//

import Foundation

@globalActor
actor BookFileCache {
  static let shared = BookFileCache()

  private let fileManager = FileManager.default
  private var downloadTasks: [String: Task<URL, Error>] = [:]

  // Cached disk cache size (static for shared access)
  private static let cacheSizeActor = CacheSizeActor()

  init() {}

  func bookRootURL(bookId: String) async -> URL {
    let url = await namespacedRootDirectory().appendingPathComponent(bookId, isDirectory: true)
    if !fileManager.fileExists(atPath: url.path) {
      try? fileManager.createDirectory(at: url, withIntermediateDirectories: true)
    }
    return url
  }

  func clear(bookId: String) async {
    let url = await namespacedRootDirectory().appendingPathComponent(bookId, isDirectory: true)
    try? fileManager.removeItem(at: url)
    await Self.cacheSizeActor.invalidate()
  }

  private func namespacedRootDirectory() async -> URL {
    await MainActor.run {
      CacheNamespace.directory(for: "KomgaBookFileCache")
    }
  }

  /// Clear disk cache for a specific book (static method for use from anywhere)
  static func clearDiskCache(forBookId bookId: String) async {
    let fileManager = FileManager.default
    let diskCacheURL = await namespacedDiskCacheURL()
    let bookCacheDir = diskCacheURL.appendingPathComponent(bookId, isDirectory: true)

    await Task.detached(priority: .userInitiated) {
      try? fileManager.removeItem(at: bookCacheDir)
    }.value

    // Invalidate cache size
    await cacheSizeActor.invalidate()
  }

  // MARK: - EPUB File Cache

  func cachedEpubFileURL(bookId: String) async -> URL? {
    let fileURL = await epubFileURL(bookId: bookId)
    return cachedFileURL(at: fileURL)
  }

  func ensureEpubFile(
    bookId: String,
    downloader: @escaping () async throws -> Data
  ) async throws -> URL {
    let destination = await epubFileURL(bookId: bookId)
    return try await ensureFile(
      bookId: bookId,
      cacheKey: "epub#\(bookId)",
      destination: destination,
      downloader: downloader
    )
  }

  private func cachedFileURL(at destination: URL) -> URL? {
    if fileManager.fileExists(atPath: destination.path) {
      return destination
    }
    return nil
  }

  private func ensureFile(
    bookId: String,
    cacheKey: String,
    destination: URL,
    downloader: @escaping () async throws -> Data
  ) async throws -> URL {
    if let existing = cachedFileURL(at: destination) {
      return existing
    }

    if let task = downloadTasks[cacheKey] {
      return try await task.value
    }

    let destinationPath = destination.path
    let task = Task<URL, Error> {
      let data = try await downloader()
      let fileManager = FileManager.default
      let destination = URL(fileURLWithPath: destinationPath)
      let directory = destination.deletingLastPathComponent()
      if !fileManager.fileExists(atPath: directory.path) {
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
      }
      try data.write(to: destination, options: [.atomic])
      return destination
    }
    downloadTasks[cacheKey] = task

    do {
      let value = try await task.value
      downloadTasks[cacheKey] = nil

      if let attributes = try? fileManager.attributesOfItem(atPath: value.path),
        let size = attributes[.size] as? Int64
      {
        // Treat as a new cached file every time ensureFile writes
        await Self.cacheSizeActor.updateSize(delta: size)
        await Self.cacheSizeActor.updateCount(delta: 1)
      } else {
        await Self.cacheSizeActor.invalidate()
      }

      return value
    } catch {
      downloadTasks[cacheKey] = nil
      throw error
    }
  }

  private func epubFileURL(bookId: String) async -> URL {
    let base = await bookRootURL(bookId: bookId)
    return base.appendingPathComponent("book.epub", isDirectory: false)
  }

  private func originalFileURL(bookId: String, fileName: String) async -> URL {
    let base = await bookRootURL(bookId: bookId)
    return base.appendingPathComponent(fileName, isDirectory: false)
  }

  /// Namespaced disk cache directory URL (static helper)
  nonisolated private static func namespacedDiskCacheURL() async -> URL {
    await MainActor.run {
      CacheNamespace.directory(for: "KomgaBookFileCache")
    }
  }

  /// Root cache directory shared by all namespaces.
  nonisolated private static func baseDiskCacheURL() -> URL {
    CacheNamespace.baseDirectory(for: "KomgaBookFileCache")
  }

  /// Clear disk cache for the current instance only
  static func clearCurrentInstanceDiskCache() async {
    let fileManager = FileManager.default
    let diskCacheURL = await namespacedDiskCacheURL()

    await Task.detached(priority: .userInitiated) {
      try? fileManager.removeItem(at: diskCacheURL)
      try? fileManager.createDirectory(at: diskCacheURL, withIntermediateDirectories: true)
    }.value

    await cacheSizeActor.set(size: 0, count: 0)
  }

  static func clearAllDiskCache() async {
    let fileManager = FileManager.default
    let diskCacheURL = baseDiskCacheURL()

    await Task.detached(priority: .userInitiated) {
      try? fileManager.removeItem(at: diskCacheURL)
      // Recreate the directory
      try? fileManager.createDirectory(at: diskCacheURL, withIntermediateDirectories: true)
    }.value

    // Reset cached size and count
    await cacheSizeActor.set(size: 0, count: 0)
  }

  /// Get disk cache size in bytes (static method for use from anywhere)
  /// Uses cached value if available, otherwise calculates and caches the result
  static func getDiskCacheSize() async -> Int64 {
    let (size, _, _) = await getDiskCacheInfo()
    return size
  }

  /// Get disk cache file count (static method for use from anywhere)
  /// Uses cached value if available, otherwise calculates and caches the result
  static func getDiskCacheCount() async -> Int {
    let (_, count, _) = await getDiskCacheInfo()
    return count
  }

  /// Get disk cache info (size and count) - internal method
  private static func getDiskCacheInfo() async -> (size: Int64, count: Int, isValid: Bool) {
    // Check cache first
    let cacheInfo = await cacheSizeActor.get()

    if cacheInfo.isValid, let size = cacheInfo.size, let count = cacheInfo.count {
      return (size, count, true)
    }

    // Cache miss or invalid, calculate size and count
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

    // Update cache
    await cacheSizeActor.set(size: result.size, count: result.count)

    return (result.size, result.count, true)
  }

  // MARK: - Private Methods

  /// Recursively collect all files in a directory
  nonisolated private static func collectFiles(at url: URL, fileManager: FileManager) -> [URL] {
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

  /// Collect file information (size and modification date) for all files
  nonisolated private static func collectFileInfo(
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
}
