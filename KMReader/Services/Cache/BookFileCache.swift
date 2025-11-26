//
//  BookFileCache.swift
//  KMReader
//
//  Created by Komga iOS Client
//

import Foundation

actor BookFileCache {
  static let shared = BookFileCache()

  private let fileManager = FileManager.default
  private let rootDirectory: URL
  private var downloadTasks: [String: Task<URL, Error>] = [:]

  // Cached disk cache size (static for shared access)
  private static let cacheSizeActor = CacheSizeActor()

  init() {
    let cachesDir = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
    rootDirectory = cachesDir.appendingPathComponent("KomgaBookFileCache", isDirectory: true)
    try? fileManager.createDirectory(at: rootDirectory, withIntermediateDirectories: true)
  }

  func bookRootURL(bookId: String) -> URL {
    let url = rootDirectory.appendingPathComponent(bookId, isDirectory: true)
    if !fileManager.fileExists(atPath: url.path) {
      try? fileManager.createDirectory(at: url, withIntermediateDirectories: true)
    }
    return url
  }

  func clear(bookId: String) {
    let url = rootDirectory.appendingPathComponent(bookId, isDirectory: true)
    try? fileManager.removeItem(at: url)
    Task {
      await Self.cacheSizeActor.invalidate()
    }
  }

  /// Clear disk cache for a specific book (static method for use from anywhere)
  static func clearDiskCache(forBookId bookId: String) async {
    let fileManager = FileManager.default
    let diskCacheURL = getDiskCacheURL()
    let bookCacheDir = diskCacheURL.appendingPathComponent(bookId, isDirectory: true)

    await Task.detached(priority: .userInitiated) {
      try? fileManager.removeItem(at: bookCacheDir)
    }.value

    // Invalidate cache size
    await cacheSizeActor.invalidate()
  }

  // MARK: - EPUB File Cache

  func cachedEpubFileURL(bookId: String) -> URL? {
    let fileURL = epubFileURL(bookId: bookId)
    if fileManager.fileExists(atPath: fileURL.path) {
      return fileURL
    }
    return nil
  }

  func ensureEpubFile(
    bookId: String,
    downloader: @escaping () async throws -> Data
  ) async throws -> URL {
    let destination = epubFileURL(bookId: bookId)
    let fileExisted = fileManager.fileExists(atPath: destination.path)

    if let existing = cachedEpubFileURL(bookId: bookId) {
      return existing
    }

    let cacheKey = "epub#\(bookId)"
    if let task = downloadTasks[cacheKey] {
      return try await task.value
    }

    // Get old file size before writing
    let oldFileSize: Int64
    if fileExisted,
      let attributes = try? fileManager.attributesOfItem(atPath: destination.path),
      let size = attributes[.size] as? Int64
    {
      oldFileSize = size
    } else {
      oldFileSize = 0
    }

    // Capture destination path for use in Task
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

      // Update cache size after storing file
      let newFileSize: Int64
      if let attributes = try? fileManager.attributesOfItem(atPath: value.path),
        let size = attributes[.size] as? Int64
      {
        newFileSize = size
      } else {
        // If we can't get file size, invalidate cache
        await Self.cacheSizeActor.invalidate()
        return value
      }

      if !fileExisted {
        // New file added
        await Self.cacheSizeActor.updateSize(delta: newFileSize)
        await Self.cacheSizeActor.updateCount(delta: 1)
      } else {
        // File was replaced, update size difference
        await Self.cacheSizeActor.updateSize(delta: newFileSize - oldFileSize)
      }

      return value
    } catch {
      downloadTasks[cacheKey] = nil
      throw error
    }
  }

  private func epubFileURL(bookId: String) -> URL {
    let base = bookRootURL(bookId: bookId)
    return base.appendingPathComponent("book.epub", isDirectory: false)
  }

  /// Get the disk cache directory URL (static helper)
  nonisolated private static func getDiskCacheURL() -> URL {
    let fileManager = FileManager.default
    let cacheDir = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
    return cacheDir.appendingPathComponent("KomgaBookFileCache", isDirectory: true)
  }

  static func clearAllDiskCache() async {
    let fileManager = FileManager.default
    let diskCacheURL = getDiskCacheURL()

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
    let diskCacheURL = getDiskCacheURL()

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
