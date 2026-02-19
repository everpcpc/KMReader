//
//  CacheManager.swift
//  KMReader
//
//

import Foundation

/// Unified cache manager for all cache types
enum CacheManager {
  /// Clear all caches for a specific book
  /// - Parameter bookId: The book ID to clear cache for
  static func clearCache(forBookId bookId: String) async {
    // Clear ImageCache (KomgaImageCache)
    await ImageCache.clearDiskCache(forBookId: bookId)

    // Clear BookFileCache (KomgaBookFileCache)
    await BookFileCache.clearDiskCache(forBookId: bookId)
  }

  /// Clear thumbnail cache
  static func clearThumbnailCache() async {
    await ThumbnailCache.clearAllDiskCache()
  }

  /// Remove all cached data for a specific Komga instance.
  static func clearCaches(instanceId: String) {
    CacheNamespace.removeNamespace(for: "KomgaImageCache", instanceId: instanceId)
    CacheNamespace.removeNamespace(for: "KomgaBookFileCache", instanceId: instanceId)
    CacheNamespace.removeNamespace(for: "KomgaThumbnailCache", instanceId: instanceId)
  }
}
