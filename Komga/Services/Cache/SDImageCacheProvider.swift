//
//  SDImageCacheProvider.swift
//  Komga
//
//  Created by Komga iOS Client
//

import Foundation
import SDWebImage

enum SDImageCacheProvider {
  static let thumbnailCache: SDImageCache = {
    let cache = SDImageCache(namespace: "KomgaThumbnailCache")
    cache.config.shouldCacheImagesInMemory = true
    cache.config.maxMemoryCost = 50 * 1024 * 1024  // 50 MB decoded thumbnails
    cache.config.maxMemoryCount = 150
    cache.config.maxDiskSize = 200 * 1024 * 1024  // 200 MB disk space
    cache.config.diskCacheExpireType = .accessDate
    return cache
  }()

  static let pageImageCache: SDImageCache = {
    let cache = SDImageCache(namespace: "KomgaPageImageCache")
    cache.config.shouldCacheImagesInMemory = true
    cache.config.maxMemoryCost = 300 * 1024 * 1024  // 300 MB decoded pages
    cache.config.maxMemoryCount = 60
    cache.config.maxDiskSize = 10 * 1024 * 1024  // Minimal disk footprint; actual storage handled elsewhere
    cache.config.diskCacheExpireType = .accessDate
    return cache
  }()

  static let thumbnailManager: SDWebImageManager = {
    SDWebImageManager(cache: thumbnailCache, loader: SDWebImageDownloader.shared)
  }()

  static let pageImageManager: SDWebImageManager = {
    SDWebImageManager(cache: pageImageCache, loader: SDWebImageDownloader.shared)
  }()
}
