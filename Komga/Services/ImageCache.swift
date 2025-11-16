//
//  ImageCache.swift
//  Komga
//
//  Created by Komga iOS Client
//

import Foundation
import SwiftUI
import UIKit

/// A two-tier cache system: disk cache + memory cache
/// Disk cache stores raw image data to avoid re-downloading
/// Memory cache stores decoded images for fast display
@MainActor
class ImageCache {
  // Memory cache (LRU)
  private var memoryCache: [Int: CacheEntry] = [:]
  private var accessOrder: [Int] = []  // LRU order: most recently used at the end
  private let maxMemoryCount: Int
  private let maxMemoryBytes: Int
  private var currentMemoryBytes: Int = 0

  // Disk cache
  private let diskCacheURL: URL
  private let fileManager = FileManager.default
  private let maxDiskCacheSizeMB: Int

  struct CacheEntry {
    let image: Image
    var lastAccessed: Date

    var memorySize: Int {
      // Estimate memory size: width * height * 4 bytes (RGBA)
      // For SwiftUI Image, we estimate based on typical display size
      // This is approximate since SwiftUI Image doesn't expose size directly
      return 4 * 1024 * 1024  // Estimate 4MB per image
    }
  }

  init(maxMemoryCount: Int = 50, maxMemoryMB: Int = 200, maxDiskCacheMB: Int = 2048) {
    self.maxMemoryCount = maxMemoryCount
    self.maxMemoryBytes = maxMemoryMB * 1024 * 1024
    self.maxDiskCacheSizeMB = maxDiskCacheMB

    // Setup disk cache directory
    let cacheDir = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
    diskCacheURL = cacheDir.appendingPathComponent("KomgaImageCache", isDirectory: true)

    // Create cache directory if needed
    try? fileManager.createDirectory(at: diskCacheURL, withIntermediateDirectories: true)

    // Listen for memory warnings
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(handleMemoryWarning),
      name: UIApplication.didReceiveMemoryWarningNotification,
      object: nil
    )

    // Clean up old disk cache on init
    Task {
      await cleanupDiskCache()
    }
  }

  deinit {
    NotificationCenter.default.removeObserver(self)
  }

  // MARK: - Public API

  /// Get image from cache (memory first, then disk)
  func getImage(forKey key: Int, bookId: String) async -> Image? {
    // Try memory cache first
    if let entry = memoryCache[key] {
      // Update access order
      updateAccessOrder(key: key)
      memoryCache[key] = CacheEntry(image: entry.image, lastAccessed: Date())
      return entry.image
    }

    // Try disk cache
    if let image = await loadFromDisk(key: key, bookId: bookId) {
      // Load into memory cache
      let entry = CacheEntry(image: image, lastAccessed: Date())
      addToMemoryCache(key: key, entry: entry)
      return image
    }

    return nil
  }

  /// Get raw image data from disk cache (for re-decoding)
  func getImageData(forKey key: Int, bookId: String) async -> Data? {
    let fileURL = diskCacheFileURL(key: key, bookId: bookId)
    return try? Data(contentsOf: fileURL)
  }

  /// Check if image exists in cache (memory or disk)
  func hasImage(forKey key: Int, bookId: String) -> Bool {
    // Check memory cache
    if memoryCache[key] != nil {
      return true
    }
    // Check disk cache
    let fileURL = diskCacheFileURL(key: key, bookId: bookId)
    return fileManager.fileExists(atPath: fileURL.path)
  }

  /// Get UIImage from cache (for UIKit compatibility)
  func getUIImage(forKey key: Int, bookId: String) async -> UIImage? {
    // Try to get from disk cache and decode
    if let data = await getImageData(forKey: key, bookId: bookId) {
      return await decodeImage(from: data)
    }
    return nil
  }

  /// Store image data to disk cache and optionally to memory cache
  func storeImageData(_ data: Data, forKey key: Int, bookId: String) async {
    let fileURL = diskCacheFileURL(key: key, bookId: bookId)
    try? data.write(to: fileURL)
  }

  /// Store decoded image to memory cache
  func storeImage(_ image: Image, forKey key: Int) {
    let entry = CacheEntry(image: image, lastAccessed: Date())
    addToMemoryCache(key: key, entry: entry)
  }

  func remove(_ key: Int) {
    evictFromMemory(key: key)
  }

  func removeAll() {
    memoryCache.removeAll()
    accessOrder.removeAll()
    currentMemoryBytes = 0
  }

  func removePagesNotInRange(_ range: Range<Int>, keepCount: Int = 3) {
    // Keep pages in range and a few pages outside the range
    let keepRange =
      max(0, range.lowerBound - keepCount)..<min(Int.max, range.upperBound + keepCount)

    let keysToRemove = memoryCache.keys.filter { !keepRange.contains($0) }
    for key in keysToRemove {
      evictFromMemory(key: key)
    }
  }

  func clearDiskCache(forBookId bookId: String) {
    let bookCacheDir = diskCacheURL.appendingPathComponent(bookId, isDirectory: true)
    try? fileManager.removeItem(at: bookCacheDir)
  }

  // MARK: - Private Methods

  private func diskCacheFileURL(key: Int, bookId: String) -> URL {
    let bookCacheDir = diskCacheURL.appendingPathComponent(bookId, isDirectory: true)
    try? fileManager.createDirectory(at: bookCacheDir, withIntermediateDirectories: true)
    return bookCacheDir.appendingPathComponent("page_\(key).data")
  }

  private func loadFromDisk(key: Int, bookId: String) async -> Image? {
    let fileURL = diskCacheFileURL(key: key, bookId: bookId)
    guard fileManager.fileExists(atPath: fileURL.path),
      let data = try? Data(contentsOf: fileURL),
      let uiImage = await decodeImage(from: data)
    else {
      return nil
    }

    return Image(uiImage: uiImage)
  }

  func decodeImage(from data: Data) async -> UIImage? {
    // Get screen size on main thread before background processing
    let screenSize = await MainActor.run {
      UIScreen.main.bounds.size
    }
    let screenScale = await MainActor.run {
      UIScreen.main.scale
    }

    return await Task.detached(priority: .userInitiated) {
      guard let image = UIImage(data: data) else { return nil }

      // Use pre-fetched screen size for downscaling
      let maxDisplaySize = CGSize(
        width: screenSize.width * screenScale * 2,
        height: screenSize.height * screenScale * 2
      )

      // Downscale if needed
      if image.size.width > maxDisplaySize.width || image.size.height > maxDisplaySize.height {
        let scale = min(
          maxDisplaySize.width / image.size.width,
          maxDisplaySize.height / image.size.height
        )
        let scaledSize = CGSize(
          width: image.size.width * scale,
          height: image.size.height * scale
        )

        UIGraphicsBeginImageContextWithOptions(scaledSize, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: scaledSize))
        let scaledImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return scaledImage ?? image
      }

      // Decode image
      UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale)
      image.draw(at: .zero)
      let decodedImage = UIGraphicsGetImageFromCurrentImageContext()
      UIGraphicsEndImageContext()

      return decodedImage ?? image
    }.value
  }

  private func addToMemoryCache(key: Int, entry: CacheEntry) {
    let entrySize = entry.memorySize

    // Remove existing entry if present
    if let existingEntry = memoryCache[key] {
      currentMemoryBytes -= existingEntry.memorySize
      if let index = accessOrder.firstIndex(of: key) {
        accessOrder.remove(at: index)
      }
    }

    // Check if we need to evict entries
    while !accessOrder.isEmpty
      && (memoryCache.count >= maxMemoryCount || currentMemoryBytes + entrySize > maxMemoryBytes)
    {
      if let lruKey = accessOrder.first {
        evictFromMemory(key: lruKey)
      } else {
        break
      }
    }

    // Add new entry
    memoryCache[key] = entry
    accessOrder.append(key)
    currentMemoryBytes += entrySize
  }

  private func evictFromMemory(key: Int) {
    guard let entry = memoryCache[key] else {
      return
    }

    currentMemoryBytes -= entry.memorySize
    memoryCache.removeValue(forKey: key)
    if let index = accessOrder.firstIndex(of: key) {
      accessOrder.remove(at: index)
    }
  }

  private func updateAccessOrder(key: Int) {
    if let index = accessOrder.firstIndex(of: key) {
      accessOrder.remove(at: index)
    }
    accessOrder.append(key)
  }

  private func cleanupDiskCache() async {
    // Calculate total disk cache size and clean up in background task
    await Task.detached(priority: .utility) { [diskCacheURL, maxDiskCacheSizeMB, fileManager] in
      // Recursively collect all files
      func collectFiles(at url: URL) -> [URL] {
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
            files.append(contentsOf: collectFiles(at: item))
          } else {
            files.append(item)
          }
        }
        return files
      }

      let allFiles = collectFiles(at: diskCacheURL)
      var totalSize: Int64 = 0
      var fileURLs: [(url: URL, size: Int64, date: Date)] = []

      for fileURL in allFiles {
        if let resourceValues = try? fileURL.resourceValues(forKeys: [
          .fileSizeKey, .contentModificationDateKey,
        ]),
          let size = resourceValues.fileSize,
          let date = resourceValues.contentModificationDate
        {
          totalSize += Int64(size)
          fileURLs.append((url: fileURL, size: Int64(size), date: date))
        }
      }

      // If over limit, remove oldest files
      let maxSize = Int64(maxDiskCacheSizeMB) * 1024 * 1024
      if totalSize > maxSize {
        fileURLs.sort { $0.date < $1.date }
        var currentSize = totalSize
        for fileInfo in fileURLs {
          if currentSize <= maxSize {
            break
          }
          try? fileManager.removeItem(at: fileInfo.url)
          currentSize -= fileInfo.size
        }
      }
    }.value
  }

  @objc private func handleMemoryWarning() {
    // On memory warning, reduce cache to half
    let targetCount = max(3, maxMemoryCount / 2)
    while memoryCache.count > targetCount {
      if let lruKey = accessOrder.first {
        evictFromMemory(key: lruKey)
      } else {
        break
      }
    }
  }

  var memoryCacheCount: Int {
    memoryCache.count
  }

  var memoryUsageMB: Double {
    Double(currentMemoryBytes) / (1024 * 1024)
  }
}
