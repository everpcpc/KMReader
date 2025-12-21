//
//  ImageCache.swift
//  Komga
//
//  Created by Komga iOS Client
//

import Foundation
import OSLog
import SwiftUI

/// Disk cache system for storing raw image data
/// Used to avoid re-downloading images. Decoding is handled by SDWebImage or on-demand.
actor ImageCache {
  // Logger for cache operations
  private let logger = AppLogger(.cache)

  // Disk cache
  private let diskCacheURL: URL
  private let fileManager = FileManager.default
  private let maxPageCacheSize: Int

  // Get max page cache size from AppConfig (with fallback to default)
  private static func getMaxPageCacheSize() -> Int {
    AppConfig.maxPageCacheSize
  }

  // Cached disk cache size (static for shared access)
  private static let cacheSizeActor = CacheSizeActor()

  init(maxPageCacheSize: Int = 8) {
    self.maxPageCacheSize = maxPageCacheSize

    // Setup disk cache directory scoped to the active server namespace
    diskCacheURL = CacheNamespace.directory(for: "KomgaImageCache")

    // Clean up old disk cache on init
    Task {
      await cleanupDiskCache()
    }
  }

  // MARK: - Public API

  /// Check if image exists in disk cache
  func hasImage(bookId: String, page: BookPage) -> Bool {
    guard !bookId.isEmpty else { return false }
    let fileURL = imageFileURL(bookId: bookId, page: page)
    return FileManager.default.fileExists(atPath: fileURL.path)
  }

  /// Get cached image URL (creates no directories, may not exist on disk)
  nonisolated func imageFileURL(bookId: String, page: BookPage) -> URL {
    diskCacheFileURL(bookId: bookId, page: page, ensureDirectory: false)
  }

  /// Store image data to disk cache
  func storeImageData(_ data: Data, bookId: String, page: BookPage) async {
    guard !bookId.isEmpty else { return }

    let fileURL = diskCacheFileURL(bookId: bookId, page: page, ensureDirectory: true)

    let oldFileSize: Int64?
    if fileManager.fileExists(atPath: fileURL.path),
      let attributes = try? fileManager.attributesOfItem(atPath: fileURL.path),
      let size = attributes[.size] as? Int64
    {
      oldFileSize = size
    } else {
      oldFileSize = nil
    }

    // Check cache size before storing and trigger cleanup if needed
    let (currentSize, _, isValid) = await Self.cacheSizeActor.get()
    let maxCacheSize = Self.getMaxPageCacheSize()
    let maxSize = Int64(maxCacheSize) * 1024 * 1024 * 1024
    let newFileSize = Int64(data.count)

    // Helper to trigger cleanup asynchronously
    func triggerCleanupIfNeeded() {
      Task.detached(priority: .utility) {
        await Self.cleanupDiskCacheIfNeeded()
      }
    }

    // If cache size info is invalid or exceeds limit, trigger cleanup
    if !isValid {
      triggerCleanupIfNeeded()
    } else if let size = currentSize {
      // Check if current size (before adding new file) would exceed limit
      let sizeAfterAdd = size - (oldFileSize ?? 0) + newFileSize
      // Trigger cleanup if cache size exceeds 90% of max size to be more proactive
      if sizeAfterAdd > maxSize * 90 / 100 {
        triggerCleanupIfNeeded()
      }
    }

    let fileExisted = fileManager.fileExists(atPath: fileURL.path)

    // Write data to disk cache
    do {
      try data.write(to: fileURL)
    } catch {
      // Log write failure
      let dataSize = ByteCountFormatter.string(
        fromByteCount: Int64(data.count), countStyle: .binary)
      logger.error(
        "❌ Failed to write image cache for bookId \(bookId) page \(page.number) (\(page.fileName)) (\(dataSize)): \(error)"
      )
      // If write fails, don't update cache size/count
      // This ensures cache state remains consistent
      return
    }

    // Update cached size and count (only if cache is valid, otherwise it will be recalculated on next get)
    await Self.cacheSizeActor.updateSize(delta: newFileSize - (oldFileSize ?? 0))
    if !fileExisted {
      // New file added
      await Self.cacheSizeActor.updateCount(delta: 1)
    }

    // Check again after storing to ensure we're within limits
    let (sizeAfterStore, _, isValidAfter) = await Self.cacheSizeActor.get()
    if isValidAfter, let size = sizeAfterStore, size > maxSize {
      // Cache exceeded limit after storing, trigger immediate cleanup
      triggerCleanupIfNeeded()
    }
  }

  func clearDiskCache(forBookId bookId: String) {
    let bookCacheDir = diskCacheURL.appendingPathComponent(bookId, isDirectory: true)
    try? fileManager.removeItem(at: bookCacheDir)
    Task {
      await Self.cacheSizeActor.invalidate()
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

  /// Clear all disk cache (static method for use from anywhere)
  static func clearAllDiskCache() async {
    let fileManager = FileManager.default
    let diskCacheURL = CacheNamespace.baseDirectory(for: "KomgaImageCache")

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

  /// Cleanup disk cache if needed (static method for use from anywhere)
  /// Checks current cache size against configured max size and cleans up if needed
  static func cleanupDiskCacheIfNeeded() async {
    let fileManager = FileManager.default
    let diskCacheURL = await namespacedDiskCacheURL()
    let maxCacheSize = getMaxPageCacheSize()

    await Task.detached(priority: .utility) {
      await performDiskCacheCleanup(
        diskCacheURL: diskCacheURL,
        fileManager: fileManager,
        maxCacheSize: maxCacheSize
      )
    }.value
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

  /// Namespaced disk cache directory URL (static helper)
  nonisolated private static func namespacedDiskCacheURL() async -> URL {
    await MainActor.run {
      CacheNamespace.directory(for: "KomgaImageCache")
    }
  }

  /// Recursively collect all files in a directory
  static func collectFiles(at url: URL, fileManager: FileManager) -> [URL] {
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
  static func collectFileInfo(
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

  /// Perform disk cache cleanup
  static func performDiskCacheCleanup(
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
      // Sort by date (oldest first) and remove until under limit
      let sortedFiles = fileInfo.sorted {
        ($0.date ?? Date.distantPast) < ($1.date ?? Date.distantPast)
      }
      var currentSize = totalSize
      for fileInfo in sortedFiles {
        if currentSize <= maxSize {
          break
        }
        try? fileManager.removeItem(at: fileInfo.url)
        currentSize -= fileInfo.size
      }
      // Invalidate cache after cleanup
      await cacheSizeActor.invalidate()
    } else {
      // Update cache with calculated size and count
      await cacheSizeActor.set(size: totalSize, count: fileInfo.count)
    }
  }

  nonisolated private func diskCacheFileURL(
    bookId: String,
    page: BookPage,
    ensureDirectory: Bool
  ) -> URL {
    // Note: This matches the implementation used in imageFileURL but allows folder creation
    // We construct path manually to be safe for non-isolated access
    let diskCacheURL = CacheNamespace.baseDirectory(for: "KomgaImageCache")
    let bookCacheDir = diskCacheURL.appendingPathComponent(bookId, isDirectory: true)
    let pageDirectory =
      bookCacheDir
      .appendingPathComponent("page", isDirectory: true)
      .appendingPathComponent("\(page.number)", isDirectory: true)

    if ensureDirectory {
      try? FileManager.default.createDirectory(at: pageDirectory, withIntermediateDirectories: true)
    }

    let sanitizedFileName = (page.fileName as NSString).lastPathComponent
    let resolvedFileName =
      sanitizedFileName.isEmpty ? "page-\(page.number)" : sanitizedFileName
    return pageDirectory.appendingPathComponent(resolvedFileName)
  }

  private func cleanupDiskCache() async {
    // Calculate total disk cache size and clean up in background task
    let maxCacheSize = Self.getMaxPageCacheSize()
    await Task.detached(priority: .utility) { [diskCacheURL, fileManager, maxCacheSize] in
      await Self.performDiskCacheCleanup(
        diskCacheURL: diskCacheURL,
        fileManager: fileManager,
        maxCacheSize: maxCacheSize
      )
    }.value
  }

}
