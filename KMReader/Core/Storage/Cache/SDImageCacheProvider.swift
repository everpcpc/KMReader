//
//  SDImageCacheProvider.swift
//  Komga
//
//  Created by Komga iOS Client
//

import Foundation
import SDWebImage
import SDWebImageWebPCoder

enum SDImageCacheProvider {
  static let thumbnailCache: SDImageCache = {
    let cache = SDImageCache(namespace: "KomgaThumbnailCache", diskCacheDirectory: nil)
    cache.config.shouldCacheImagesInMemory = true
    cache.config.maxMemoryCost = 50 * 1024 * 1024  // 50 MB decoded thumbnails
    cache.config.maxMemoryCount = 200
    return cache
  }()

  static let pageImageCache: SDImageCache = {
    let cache = SDImageCache(namespace: "KomgaPageImageCache", diskCacheDirectory: nil)
    cache.config.shouldCacheImagesInMemory = true
    cache.config.maxMemoryCost = 200 * 1024 * 1024  // 200 MB decoded pages
    cache.config.maxMemoryCount = 50
    return cache
  }()

  static let thumbnailManager: SDWebImageManager = {
    SDWebImageManager(cache: thumbnailCache, loader: SDWebImageDownloader.shared)
  }()

  static let pageImageManager: SDWebImageManager = {
    SDWebImageManager(cache: pageImageCache, loader: SDWebImageDownloader.shared)
  }()

  static func configureSDWebImage() {
    // Register WebP coder
    SDImageCodersManager.shared.addCoder(SDImageWebPCoder.shared)
  }
}
