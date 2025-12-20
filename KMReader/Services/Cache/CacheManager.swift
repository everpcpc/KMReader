//
//  CacheManager.swift
//  KMReader
//
//  Created by Komga iOS Client
//

import Foundation
import SDWebImage

/// Unified cache manager for all cache types
enum CacheManager {
  /// Clear all caches for a specific book
  /// - Parameter bookId: The book ID to clear cache for
  static func clearCache(forBookId bookId: String) async {
    // Clear ImageCache (KomgaImageCache)
    await ImageCache.clearDiskCache(forBookId: bookId)

    // Clear BookFileCache (KomgaBookFileCache)
    await BookFileCache.clearDiskCache(forBookId: bookId)

    // Clear SDWebImage caches
    // Note: SDWebImage doesn't support clearing by bookId directly,
    // but we clear memory cache which may contain images for this book
    SDImageCacheProvider.thumbnailCache.clearMemory()
    SDImageCacheProvider.pageImageCache.clearMemory()
  }

  /// Clear thumbnail cache
  static func clearThumbnailCache() async {
    await ThumbnailCache.clearAllDiskCache()
    await MainActor.run {
      SDImageCacheProvider.thumbnailCache.clearMemory()
      SDImageCacheProvider.thumbnailCache.clearDisk()
    }
  }

  /// Remove all cached data for a specific Komga instance.
  static func clearCaches(instanceId: String) {
    CacheNamespace.removeNamespace(for: "KomgaImageCache", instanceId: instanceId)
    CacheNamespace.removeNamespace(for: "KomgaBookFileCache", instanceId: instanceId)
    CacheNamespace.removeNamespace(for: "KomgaThumbnailCache", instanceId: instanceId)
  }
}
