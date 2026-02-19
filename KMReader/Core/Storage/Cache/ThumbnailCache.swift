//
// ThumbnailCache.swift
//
//

import Foundation
import ImageIO
import OSLog
import UniformTypeIdentifiers

extension Notification.Name {
  static let thumbnailDidRefresh = Notification.Name("thumbnailDidRefresh")
}

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
  private static let cleanupHighWatermarkPercent: Int64 = 90
  private static let cleanupTargetPercent: Int64 = 80
  private static let cleanupThrottleInterval: TimeInterval = 5

  private static func getMaxDiskCacheSize() -> Int {
    AppConfig.maxCoverCacheSize
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
      let oldFileSize: Int64?
      if FileManager.default.fileExists(atPath: fileURL.path),
        let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
        let size = attributes[.size] as? Int64
      {
        oldFileSize = size
      } else {
        oldFileSize = nil
      }

      let maxSize = Int64(Self.getMaxDiskCacheSize()) * 1024 * 1024
      let highWatermark = maxSize * Self.cleanupHighWatermarkPercent / 100
      let newFileSize = Int64(data.count)
      let (currentSize, _, isValid) = await Self.cacheSizeActor.get()

      func triggerCleanupIfNeeded() {
        Task.detached(priority: .utility) {
          await Self.cleanupDiskCacheIfNeeded()
        }
      }

      if !isValid {
        triggerCleanupIfNeeded()
      } else if let size = currentSize {
        let sizeAfterAdd = size - (oldFileSize ?? 0) + newFileSize
        if sizeAfterAdd > highWatermark {
          triggerCleanupIfNeeded()
        }
      }

      let fileExisted = FileManager.default.fileExists(atPath: fileURL.path)
      try data.write(to: fileURL, options: [.atomic])

      logger.info("✅ Saved thumbnail for \(type.rawValue) \(id)")

      await Self.cacheSizeActor.updateSize(delta: newFileSize - (oldFileSize ?? 0))
      if !fileExisted {
        await Self.cacheSizeActor.updateCount(delta: 1)
      }

      let (sizeAfterStore, _, isValidAfter) = await Self.cacheSizeActor.get()
      if isValidAfter, let size = sizeAfterStore, size > highWatermark {
        triggerCleanupIfNeeded()
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

    let instanceId = await MainActor.run { AppConfig.current.instanceId }

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
      let oldFileSize: Int64?
      if fileManager.fileExists(atPath: thumbnailURL.path),
        let attributes = try? fileManager.attributesOfItem(atPath: thumbnailURL.path),
        let size = attributes[.size] as? Int64
      {
        oldFileSize = size
      } else {
        oldFileSize = nil
      }

      let maxSize = Int64(Self.getMaxDiskCacheSize()) * 1024 * 1024
      let highWatermark = maxSize * Self.cleanupHighWatermarkPercent / 100
      let newFileSize = Int64(thumbnailData.count)
      let (currentSize, _, isValid) = await Self.cacheSizeActor.get()

      func triggerCleanupIfNeeded() {
        Task.detached(priority: .utility) {
          await Self.cleanupDiskCacheIfNeeded()
        }
      }

      if !isValid {
        triggerCleanupIfNeeded()
      } else if let size = currentSize {
        let sizeAfterAdd = size - (oldFileSize ?? 0) + newFileSize
        if sizeAfterAdd > highWatermark {
          triggerCleanupIfNeeded()
        }
      }

      let fileExisted = fileManager.fileExists(atPath: thumbnailURL.path)
      try thumbnailData.write(to: thumbnailURL, options: [.atomic])
      logger.info("✅ Generated thumbnail from offline page for book \(bookId) page \(pageNumber)")

      await Self.cacheSizeActor.updateSize(delta: newFileSize - (oldFileSize ?? 0))
      if !fileExisted {
        await Self.cacheSizeActor.updateCount(delta: 1)
      }

      let (sizeAfterStore, _, isValidAfter) = await Self.cacheSizeActor.get()
      if isValidAfter, let size = sizeAfterStore, size > highWatermark {
        triggerCleanupIfNeeded()
      }

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
    let maxCacheSize = getMaxDiskCacheSize()
    let maxSize = Int64(maxCacheSize) * 1024 * 1024
    let highWatermark = maxSize * cleanupHighWatermarkPercent / 100
    let (cachedSize, _, isValid) = await cacheSizeActor.get()

    if isValid, let cachedSize, cachedSize <= highWatermark {
      return
    }

    guard
      await cacheSizeActor.tryBeginCleanup(
        minInterval: cleanupThrottleInterval,
        force: !isValid
      )
    else {
      return
    }

    let diskCacheURL = await namespacedDiskCacheURL()

    await Task.detached(priority: .utility) {
      await performDiskCacheCleanup(
        diskCacheURL: diskCacheURL,
        fileManager: fileManager,
        maxCacheSize: maxCacheSize
      )
    }.value

    await cacheSizeActor.endCleanup()
  }

  /// Refresh thumbnail by re-downloading from server
  /// - Parameters:
  ///   - id: The entity ID
  ///   - type: The thumbnail type
  static func refreshThumbnail(id: String, type: ThumbnailType) async throws {
    _ = try await shared.ensureThumbnail(id: id, type: type, force: true)

    await MainActor.run {
      NotificationCenter.default.post(
        name: .thumbnailDidRefresh,
        object: nil,
        userInfo: ["id": id, "type": type.rawValue]
      )
    }
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

  private static func collectFileInfo(
    at diskCacheURL: URL,
    fileManager: FileManager,
    includeDate: Bool = false
  ) -> (files: [URL], fileInfo: [(url: URL, size: Int64, date: Date?)], totalSize: Int64) {
    let resourceKeys: [URLResourceKey] =
      includeDate
      ? [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey]
      : [.isDirectoryKey, .fileSizeKey]
    let resourceKeySet = Set(resourceKeys)

    guard
      let enumerator = fileManager.enumerator(
        at: diskCacheURL,
        includingPropertiesForKeys: resourceKeys,
        options: [.skipsHiddenFiles]
      )
    else {
      return ([], [], 0)
    }

    var allFiles: [URL] = []
    var totalSize: Int64 = 0
    var fileInfo: [(url: URL, size: Int64, date: Date?)] = []

    for case let fileURL as URL in enumerator {
      guard
        let resourceValues = try? fileURL.resourceValues(forKeys: resourceKeySet),
        resourceValues.isDirectory != true,
        let fileSize = resourceValues.fileSize
      else {
        continue
      }

      let size = Int64(fileSize)
      totalSize += size
      allFiles.append(fileURL)
      fileInfo.append((url: fileURL, size: size, date: resourceValues.contentModificationDate))
    }

    return (allFiles, fileInfo, totalSize)
  }

  private static func performDiskCacheCleanup(
    diskCacheURL: URL,
    fileManager: FileManager,
    maxCacheSize: Int
  ) async {
    let logger = AppLogger(.cache)
    let maxSize = Int64(maxCacheSize) * 1024 * 1024
    let highWatermark = maxSize * cleanupHighWatermarkPercent / 100
    let targetSize = maxSize * cleanupTargetPercent / 100
    let (_, fileInfo, totalSize) = collectFileInfo(
      at: diskCacheURL,
      fileManager: fileManager,
      includeDate: true
    )

    // Check validity state BEFORE deleting to decide strategy
    let (_, _, isValid) = await cacheSizeActor.get()

    if totalSize > highWatermark {
      logger.debug(
        "🧹 [CoverCache] Cleanup start: total=\(totalSize)B high=\(highWatermark)B target=\(targetSize)B files=\(fileInfo.count)"
      )

      let oldestFirst = fileInfo.sorted {
        ($0.date ?? Date.distantPast) < ($1.date ?? Date.distantPast)
      }
      var currentSize = totalSize
      var bytesDeleted: Int64 = 0
      var filesDeleted = 0

      for info in oldestFirst {
        if currentSize <= targetSize { break }

        do {
          try fileManager.removeItem(at: info.url)
          bytesDeleted += info.size
          filesDeleted += 1
          currentSize -= info.size
        } catch {
          // Failed to delete (maybe race condition or permission).
          // Do not update counts for this file.
        }
      }

      if isValid {
        await cacheSizeActor.updateSize(delta: -bytesDeleted)
        await cacheSizeActor.updateCount(delta: -filesDeleted)
      } else {
        // If invalid, we must set the absolute value.
        // We use our scanned values minus what WE deleted.
        await cacheSizeActor.set(size: totalSize - bytesDeleted, count: fileInfo.count - filesDeleted)
      }

      logger.debug(
        "🧹 [CoverCache] Cleanup end: deletedFiles=\(filesDeleted) freed=\(bytesDeleted)B remaining=\(max(0, totalSize - bytesDeleted))B"
      )
    } else {
      // scanned size is within limits.
      // IF cache was valid, we do NOTHING (to avoid overwriting concurrent writes).
      // IF cache was invalid, we set it (sync).
      if !isValid {
        await cacheSizeActor.set(size: totalSize, count: fileInfo.count)
      }
    }
  }
}
