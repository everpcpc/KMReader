//
// CacheManager.swift
//
//

import Foundation

/// Unified cache manager for all cache types
enum CacheManager {
  /// Clear all caches for a specific book
  /// - Parameter bookId: The book ID to clear cache for
  static func clearCache(forBookId bookId: String) async {
    await ImageCache.clearDiskCache(forBookId: bookId)
  }

  /// Clear thumbnail cache
  static func clearThumbnailCache() async {
    await ThumbnailCache.clearAllDiskCache()
  }

  /// Remove all cached data for a specific Komga instance.
  static func clearCaches(instanceId: String) {
    CacheNamespace.removeNamespace(for: "KomgaImageCache", instanceId: instanceId)
    // Remove historical leftovers from the deprecated book file cache namespace.
    CacheNamespace.removeNamespace(for: "KomgaBookFileCache", instanceId: instanceId)
    CacheNamespace.removeNamespace(for: "KomgaThumbnailCache", instanceId: instanceId)
  }
}
