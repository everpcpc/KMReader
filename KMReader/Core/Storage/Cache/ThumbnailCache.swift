//
//  ThumbnailCache.swift
//  KMReader
//
//  Created by Komga iOS Client
//

import Foundation
import ImageIO
import OSLog
import UniformTypeIdentifiers

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

@globalActor
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
  /// For page thumbnails, will attempt to generate from offline downloaded pages first.
  /// Returns the local file:// URL.
  func ensureThumbnail(id: String, type: ThumbnailType, page: Int? = nil, force: Bool = false)
    async throws -> URL
  {
    let fileURL = Self.getThumbnailFileURL(id: id, type: type, page: page)

    if !force && fileManager.fileExists(atPath: fileURL.path) {
      return fileURL
    }

    // For page thumbnails, try to generate from offline downloaded pages first
    if case .page = type, let pageNum = page {
      if let offlineURL = await generateThumbnailFromOfflinePage(
        bookId: id, pageNumber: pageNum, thumbnailURL: fileURL)
      {
        return offlineURL
      }
    }

    let cacheKey =
      page != nil
      ? "\(type.rawValue)#\(id)#\(page!)#\(force)" : "\(type.rawValue)#\(id)#\(force)"
    if let existingTask = downloadTasks[cacheKey] {
      return try await existingTask.value
    }

    let task = Task<URL, Error> {
      let logSuffix = page != nil ? "page \(page!) of book \(id)" : "\(type.rawValue) \(id)"
      if force {
        logger.info("📡 Force refreshing thumbnail for \(logSuffix)")
      } else {
        logger.info("📡 Downloading thumbnail for \(logSuffix)")
      }

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

      let isNewFile = !FileManager.default.fileExists(atPath: fileURL.path)
      try data.write(to: fileURL, options: [.atomic])

      logger.info("✅ Saved thumbnail for \(type.rawValue) \(id)")

      // Update cached size and count if new
      if isNewFile {
        let fileSize = Int64(data.count)
        await Self.cacheSizeActor.updateSize(delta: fileSize)
        await Self.cacheSizeActor.updateCount(delta: 1)
      }

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

  // MARK: - Offline Page Thumbnail Generation

  /// Generate thumbnail from offline downloaded page image
  /// - Parameters:
  ///   - bookId: The book ID
  ///   - pageNumber: The page number
  ///   - thumbnailURL: Destination URL for the generated thumbnail
  /// - Returns: URL of the generated thumbnail, or nil if generation failed
  private func generateThumbnailFromOfflinePage(
    bookId: String, pageNumber: Int, thumbnailURL: URL
  ) async -> URL? {
    // Check if book is downloaded offline
    guard await OfflineManager.shared.isBookDownloaded(bookId: bookId) else {
      return nil
    }

    let instanceId = await MainActor.run { AppConfig.currentInstanceId }

    // Try common image extensions
    let extensions = ["jpg", "jpeg", "png", "webp", "avif", "gif"]
    var offlinePageURL: URL?

    for ext in extensions {
      if let url = await OfflineManager.shared.getOfflinePageImageURL(
        instanceId: instanceId, bookId: bookId, pageNumber: pageNumber, fileExtension: ext)
      {
        offlinePageURL = url
        break
      }
    }

    guard let sourceURL = offlinePageURL else {
      logger.debug("⚠️ Offline page not found for book \(bookId) page \(pageNumber)")
      return nil
    }

    // Downsample the image to thumbnail size (300px max dimension, matching Komga API)
    guard let thumbnailData = downsampleImage(at: sourceURL, maxDimension: 300) else {
      logger.warning("⚠️ Failed to downsample offline page for book \(bookId) page \(pageNumber)")
      return nil
    }

    // Ensure directory exists
    let typeDir = thumbnailURL.deletingLastPathComponent()
    if !fileManager.fileExists(atPath: typeDir.path) {
      try? fileManager.createDirectory(at: typeDir, withIntermediateDirectories: true)
    }

    do {
      try thumbnailData.write(to: thumbnailURL, options: [.atomic])
      logger.info("✅ Generated thumbnail from offline page for book \(bookId) page \(pageNumber)")

      // Update cached size and count
      let fileSize = Int64(thumbnailData.count)
      await Self.cacheSizeActor.updateSize(delta: fileSize)
      await Self.cacheSizeActor.updateCount(delta: 1)

      return thumbnailURL
    } catch {
      logger.error(
        "❌ Failed to save generated thumbnail for book \(bookId) page \(pageNumber): \(error)")
      return nil
    }
  }

  /// Downsample an image efficiently using ImageIO
  /// - Parameters:
  ///   - url: Source image URL
  ///   - maxDimension: Maximum width or height in pixels
  /// - Returns: JPEG data of the downsampled image, or nil if failed
  private nonisolated func downsampleImage(at url: URL, maxDimension: CGFloat) -> Data? {
    let imageSourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
    guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, imageSourceOptions) else {
      return nil
    }

    let downsampleOptions =
      [
        kCGImageSourceCreateThumbnailFromImageAlways: true,
        kCGImageSourceShouldCacheImmediately: true,
        kCGImageSourceCreateThumbnailWithTransform: true,
        kCGImageSourceThumbnailMaxPixelSize: maxDimension,
      ] as CFDictionary

    guard
      let downsampledImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, downsampleOptions)
    else {
      return nil
    }

    // Convert to JPEG data
    let data = NSMutableData()
    guard
      let destination = CGImageDestinationCreateWithData(
        data, UTType.jpeg.identifier as CFString, 1, nil)
    else {
      return nil
    }
    CGImageDestinationAddImage(destination, downsampledImage, nil)
    guard CGImageDestinationFinalize(destination) else {
      return nil
    }

    return data as Data
  }

  // MARK: - Cache Management

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
