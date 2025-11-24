//
//  ReaderViewModel.swift
//  Komga
//
//  Created by Komga iOS Client
//

import Foundation
import OSLog
import Photos
import SDWebImage
import SwiftUI

struct PagePair: Hashable {
  let first: Int
  let second: Int?
  var id: Int { first }

  var display: String {
    if let second = second {
      return "\(first+1),\(second+1)"
    } else {
      return "\(first+1)"
    }
  }
}

@MainActor
@Observable
class ReaderViewModel {
  var pages: [BookPage] = []
  var currentPageIndex = 0
  var targetPageIndex: Int? = nil
  var isLoading = true
  var pageImageCache: ImageCache
  var incognitoMode: Bool = false

  var pagePairs: [PagePair] = []
  // map of page index to dual page index
  var dualPageIndices: [Int: PagePair] = [:]

  private let bookService = BookService.shared
  private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "Komga", category: "ReaderViewModel")
  /// Current book ID for API calls and cache access
  var bookId: String = ""

  /// Track ongoing download tasks to prevent duplicate downloads for the same page (keyed by page number)
  private var downloadingTasks: [Int: Task<URL?, Never>] = [:]

  var currentPage: BookPage? {
    guard currentPageIndex >= 0 else { return nil }
    guard !pages.isEmpty else { return nil }
    let clampedIndex = min(currentPageIndex, pages.count - 1)
    return pages[clampedIndex]
  }

  init() {
    self.pageImageCache = ImageCache()
    self.pagePairs = generatePagePairs(pages: pages)
    self.dualPageIndices = generateDualPageIndices(pairs: pagePairs)
  }

  func loadPages(bookId: String, initialPageNumber: Int? = nil) async {
    self.bookId = bookId
    isLoading = true

    // Cancel all ongoing download tasks when loading a new book
    for (_, task) in downloadingTasks {
      task.cancel()
    }
    downloadingTasks.removeAll()

    do {
      pages = try await bookService.getBookPages(id: bookId)

      // Update page pairs and dual page indices after loading pages
      pagePairs = generatePagePairs(pages: pages)
      dualPageIndices = generateDualPageIndices(pairs: pagePairs)

      if let initialPageNumber = initialPageNumber {
        if let pageIndex = pages.firstIndex(where: { $0.number == initialPageNumber }) {
          currentPageIndex = pageIndex
        }
      }
    } catch {
      ErrorManager.shared.alert(error: error)
    }

    isLoading = false
  }

  /// Get page image file URL from disk cache, or download and cache if not available
  /// - Parameter page: `BookPage` metadata for the requested page
  /// - Returns: Local file URL if available, nil if download failed
  /// - Note: Prevents duplicate downloads by tracking ongoing tasks
  func getPageImageFileURL(page: BookPage) async -> URL? {
    guard !bookId.isEmpty else {
      logger.warning("⚠️ Book ID is empty, cannot load page image")
      return nil
    }
    if let cachedFileURL = getCachedImageFileURL(page: page) {
      logger.debug("✅ Using cached image for page \(page.number) for book \(self.bookId)")
      return cachedFileURL
    }
    if let existingTask = downloadingTasks[page.number] {
      logger.debug(
        "⏳ Waiting for existing download task for page \(page.number) for book \(self.bookId)"
      )
      if let result = await existingTask.value {
        return result
      }
      if let cachedFileURL = getCachedImageFileURL(page: page) {
        return cachedFileURL
      }
      return nil
    }

    let downloadTask = Task<URL?, Never> {
      logger.info("📥 Downloading page \(page.number) for book \(self.bookId)")

      do {
        let result = try await bookService.getBookPage(bookId: self.bookId, page: page.number)
        let data = result.data

        let dataSize = ByteCountFormatter.string(
          fromByteCount: Int64(data.count), countStyle: .binary)
        logger.info(
          "✅ Downloaded page \(page.number) successfully (\(dataSize)) for book \(self.bookId)")

        await pageImageCache.storeImageData(
          data,
          bookId: self.bookId,
          page: page
        )

        if let fileURL = getCachedImageFileURL(page: page) {
          logger.debug("💾 Saved page \(page.number) to disk cache for book \(self.bookId)")
          return fileURL
        } else {
          logger.error(
            "❌ Failed to get file URL after saving page \(page.number) to cache for book \(self.bookId)"
          )
          return nil
        }
      } catch {
        logger.error(
          "❌ Failed to download page \(page.number) for book \(self.bookId): \(error)"
        )
        return nil
      }
    }

    downloadingTasks[page.number] = downloadTask
    let result = await downloadTask.value
    downloadingTasks.removeValue(forKey: page.number)
    return result
  }

  /// Get cached image file URL from disk cache for a specific page
  /// - Parameter page: Book page metadata
  /// - Returns: Local file URL if the cached file exists, nil otherwise
  func getCachedImageFileURL(page: BookPage) -> URL? {
    guard !bookId.isEmpty else {
      return nil
    }

    let fileURL = pageImageCache.imageFileURL(bookId: bookId, page: page)

    if FileManager.default.fileExists(atPath: fileURL.path) {
      return fileURL
    }
    return nil
  }

  /// Preload pages around the current page for smoother scrolling
  /// Preloads 2 pages before and 4 pages after the current page
  func preloadPages() async {
    guard !bookId.isEmpty else { return }
    let preloadBefore = max(0, currentPageIndex - 2)
    let preloadAfter = min(currentPageIndex + 4, pages.count)
    let pagesToPreload = Array(preloadBefore..<preloadAfter)

    // Load pages concurrently for better performance
    await withTaskGroup(of: Void.self) { group in
      for index in pagesToPreload {
        // Only preload if not already cached
        let page = pages[index]
        if !pageImageCache.hasImage(bookId: bookId, page: page) {
          group.addTask {
            _ = await self.getPageImageFileURL(page: page)
          }
        }
      }
    }
  }

  /// Update reading progress on the server
  /// Uses API page number (1-based) instead of array index (0-based)
  /// Skip update if incognito mode is enabled
  func updateProgress() async {
    // Skip progress updates in incognito mode
    guard !incognitoMode else { return }
    guard !bookId.isEmpty else { return }
    guard let currentPage = currentPage else { return }

    let completed = currentPageIndex >= pages.count - 1

    do {
      try await bookService.updatePageReadProgress(
        bookId: bookId,
        page: currentPage.number,
        completed: completed
      )
    } catch {
      // Progress updates are non-critical, fail silently
    }
  }

  /// Save page image to Photos from cache
  /// - Parameter page: Book page to save
  /// - Returns: Result indicating success or failure with error message
  func savePageImageToPhotos(page: BookPage) async -> Result<Void, SaveImageError> {
    guard !bookId.isEmpty else {
      return .failure(.bookIdEmpty)
    }

    guard let fileURL = getCachedImageFileURL(page: page) else {
      return .failure(.imageNotCached)
    }

    // Check photo library authorization
    let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
    guard status == .authorized || status == .limited else {
      return .failure(.photoLibraryAccessDenied)
    }

    let supportedTypes: [UTType] = [.jpeg, .png, .heic, .heif]
    let isSupported =
      page.detectedUTType.map { type in supportedTypes.contains { type.conforms(to: $0) } } ?? false

    if isSupported {
      do {
        try await PHPhotoLibrary.shared().performChanges {
          PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: fileURL)
        }
        return .success(())
      } catch {
        return .failure(.saveError(error.localizedDescription))
      }
    }

    // Unsupported type: convert to PNG in-memory and add via resource API
    guard let image = await loadImageWithSDWebImage(from: fileURL),
      let pngData = PlatformHelper.pngData(from: image)
    else {
      return .failure(.failedToLoadImageData)
    }

    do {
      try await PHPhotoLibrary.shared().performChanges {
        let creationRequest = PHAssetCreationRequest.forAsset()
        let options = PHAssetResourceCreationOptions()
        options.uniformTypeIdentifier = UTType.png.identifier
        creationRequest.addResource(with: .photo, data: pngData, options: options)
      }
      return .success(())
    } catch {
      return .failure(.saveError(error.localizedDescription))
    }
  }

  /// Load image using SDWebImage
  /// - Parameter fileURL: Local file URL
  /// - Returns: PlatformImage if successfully loaded, nil otherwise
  private func loadImageWithSDWebImage(from fileURL: URL) async -> PlatformImage? {
    #if canImport(UIKit)
      return await withCheckedContinuation { continuation in
        SDImageCacheProvider.pageImageCache.queryImage(
          forKey: fileURL.absoluteString,
          options: [],
          context: nil
        ) { image, data, cacheType in
          if let image = image {
            continuation.resume(returning: image)
          } else {
            if let imageData = try? Data(contentsOf: fileURL),
              let image = SDImageCodersManager.shared.decodedImage(with: imageData, options: nil)
                as? UIImage
            {
              continuation.resume(returning: image)
            } else {
              continuation.resume(returning: nil)
            }
          }
        }
      }
    #elseif canImport(AppKit)
      return await withCheckedContinuation { continuation in
        SDImageCacheProvider.pageImageCache.queryImage(
          forKey: fileURL.absoluteString,
          options: [],
          context: nil
        ) { image, data, cacheType in
          if let image = image {
            continuation.resume(returning: image)
          } else {
            if let imageData = try? Data(contentsOf: fileURL),
              let image = SDImageCodersManager.shared.decodedImage(
                with: imageData, options: nil)
            {
              continuation.resume(returning: image)
            } else {
              continuation.resume(returning: nil)
            }
          }
        }
      }
    #else
      return nil
    #endif
  }
}

private func generatePagePairs(pages: [BookPage]) -> [PagePair] {
  guard pages.count > 0 else { return [] }

  var pairs: [PagePair] = []
  let noCover = UserDefaults.standard.bool(forKey: "dualPageNoCover")

  var index = 0
  while index < pages.count {
    let currentPage = pages[index]

    var useSinglePage = false
    // force single page if the page is landscape
    if !currentPage.isPortrait {
      useSinglePage = true
    }
    // force single page if it's the first page and cover is enabled
    if !noCover && index == 0 {
      useSinglePage = true
    }
    // force single page if it's the last page
    if index == pages.count - 1 {
      useSinglePage = true
    }

    if useSinglePage {
      pairs.append(PagePair(first: index, second: nil))
      index += 1
    } else {
      // Try to pair with next page
      let nextPage = pages[index + 1]
      // Only pair if next page is also portrait
      if nextPage.isPortrait {
        pairs.append(PagePair(first: index, second: index + 1))
        index += 2
      } else {
        // Next page is not portrait, show current as single
        pairs.append(PagePair(first: index, second: nil))
        index += 1
      }
    }
  }
  // insert end page pair at the end
  pairs.append(PagePair(first: pages.count, second: nil))

  return pairs
}

private func generateDualPageIndices(pairs: [PagePair]) -> [Int: PagePair] {
  var indices: [Int: PagePair] = [:]
  for pair in pairs {
    indices[pair.first] = pair
    if let second = pair.second {
      indices[second] = pair
    }
  }
  return indices
}
