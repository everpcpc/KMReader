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
import UIKit

enum ReadingDirection: CaseIterable, Hashable {
  case ltr
  case rtl
  case vertical
  case webtoon

  static func fromString(_ direction: String) -> ReadingDirection {
    switch direction.uppercased() {
    case "LEFT_TO_RIGHT":
      return .ltr
    case "RIGHT_TO_LEFT":
      return .rtl
    case "VERTICAL":
      return .vertical
    case "WEBTOON":
      return .webtoon
    default:
      return .ltr
    }
  }

  var displayName: String {
    switch self {
    case .ltr:
      return "LTR"
    case .rtl:
      return "RTL"
    case .vertical:
      return "Vertical"
    case .webtoon:
      return "Webtoon"
    }
  }

  var icon: String {
    if #available(iOS 18.0, *) {
      switch self {
      case .ltr:
        return "inset.filled.trailinghalf.arrow.trailing.rectangle"
      case .rtl:
        return "inset.filled.leadinghalf.arrow.leading.rectangle"
      case .vertical:
        return "rectangle.portrait.bottomhalf.filled"
      case .webtoon:
        return "arrow.up.and.down.square"
      }
    } else {
      switch self {
      case .ltr:
        return "rectangle.trailinghalf.inset.filled.arrow.trailing"
      case .rtl:
        return "rectangle.leadinghalf.inset.filled.arrow.leading"
      case .vertical:
        return "rectangle.portrait.bottomhalf.filled"
      case .webtoon:
        return "arrow.up.and.down.square"
      }
    }
  }
}

@MainActor
@Observable
class ReaderViewModel {
  var pages: [BookPage] = []
  var currentPage = 0
  var isLoading = false
  var errorMessage: String?
  var pageImageCache: ImageCache
  var readingDirection: ReadingDirection = .ltr

  private let bookService = BookService.shared
  private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "Komga", category: "ReaderViewModel")
  /// Current book ID for API calls and cache access
  var bookId: String = ""

  /// Track ongoing download tasks to prevent duplicate downloads for the same page
  private var downloadingTasks: [Int: Task<URL?, Never>] = [:]

  init() {
    self.pageImageCache = ImageCache()
  }

  func loadPages(bookId: String, initialPage: Int? = nil) async {
    self.bookId = bookId
    isLoading = true
    errorMessage = nil

    // Cancel all ongoing download tasks when loading a new book
    for (_, task) in downloadingTasks {
      task.cancel()
    }
    downloadingTasks.removeAll()

    do {
      pages = try await bookService.getBookPages(id: bookId)

      // Set initial page if provided
      // Note: API page numbers are 1-based, but array indices are 0-based
      if let initialPage = initialPage {
        if let pageIndex = pages.firstIndex(where: { $0.number == initialPage }) {
          currentPage = pageIndex
        }
      }
    } catch {
      errorMessage = error.localizedDescription
    }

    isLoading = false
  }

  /// Get page image file URL from disk cache, or download and cache if not available
  /// - Parameter pageIndex: Zero-based page index
  /// - Returns: Local file URL if available, nil if download failed
  /// - Note: Prevents duplicate downloads by tracking ongoing tasks
  func getPageImageFileURL(pageIndex: Int) async -> URL? {
    guard pageIndex >= 0 && pageIndex < pages.count else {
      logger.warning(
        "⚠️ Invalid page index: \(pageIndex) (total pages: \(self.pages.count)) for book \(self.bookId)"
      )
      return nil
    }

    guard !bookId.isEmpty else {
      logger.warning("⚠️ Book ID is empty, cannot load page image")
      return nil
    }

    // Check if already cached
    if let cachedFileURL = getCachedImageFileURL(pageIndex: pageIndex) {
      logger.debug(
        "✅ Using cached image for page \(self.pages[pageIndex].number) (index: \(pageIndex)) for book \(self.bookId)"
      )
      return cachedFileURL
    }

    // Check if there's already a download task for this page
    if let existingTask = downloadingTasks[pageIndex] {
      logger.debug(
        "⏳ Waiting for existing download task for page \(self.pages[pageIndex].number) (index: \(pageIndex)) for book \(self.bookId)"
      )
      // Wait for the existing task to complete
      if let result = await existingTask.value {
        return result
      }
      // If the existing task returned nil, check cache again
      // (the file might have been saved by another concurrent request)
      if let cachedFileURL = getCachedImageFileURL(pageIndex: pageIndex) {
        return cachedFileURL
      }
      return nil
    }

    // Not cached and no existing task, create a new download task
    let apiPageNumber = pages[pageIndex].number
    let downloadTask = Task<URL?, Never> {
      logger.info(
        "📥 Downloading page \(apiPageNumber) (index: \(pageIndex)) for book \(self.bookId)")

      do {
        let data = try await bookService.getBookPage(bookId: self.bookId, page: apiPageNumber)

        let dataSize = ByteCountFormatter.string(
          fromByteCount: Int64(data.count), countStyle: .binary)
        logger.info(
          "✅ Downloaded page \(apiPageNumber) successfully (\(dataSize)) for book \(self.bookId)")

        // Save raw image data to disk cache (decoding is handled by SDWebImage)
        await pageImageCache.storeImageData(data, forKey: pageIndex, bookId: self.bookId)

        // Return the cached file URL
        if let fileURL = getCachedImageFileURL(pageIndex: pageIndex) {
          logger.debug("💾 Saved page \(apiPageNumber) to disk cache for book \(self.bookId)")
          return fileURL
        } else {
          logger.error(
            "❌ Failed to get file URL after saving page \(apiPageNumber) to cache for book \(self.bookId)"
          )
          return nil
        }
      } catch {
        // Download failed
        logger.error(
          "❌ Failed to download page \(apiPageNumber) (index: \(pageIndex)) for book \(self.bookId): \(error.localizedDescription)"
        )
        return nil
      }
    }

    // Store the task
    downloadingTasks[pageIndex] = downloadTask

    // Wait for the task to complete
    let result = await downloadTask.value

    // Remove the task from the dictionary
    downloadingTasks.removeValue(forKey: pageIndex)

    return result
  }

  /// Get cached image file URL from disk cache
  /// - Parameter pageIndex: Zero-based page index
  /// - Returns: Local file URL if the cached file exists, nil otherwise
  private func getCachedImageFileURL(pageIndex: Int) -> URL? {
    // Construct the file path: CacheDirectory/KomgaImageCache/{bookId}/page_{index}.data
    let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
    let diskCacheURL = cacheDir.appendingPathComponent("KomgaImageCache", isDirectory: true)
    let bookCacheDir = diskCacheURL.appendingPathComponent(bookId, isDirectory: true)
    let fileURL = bookCacheDir.appendingPathComponent("page_\(pageIndex).data")

    // Verify file exists before returning URL
    if FileManager.default.fileExists(atPath: fileURL.path) {
      return fileURL
    }
    return nil
  }

  /// Preload pages around the current page for smoother scrolling
  /// Preloads 2 pages before and 4 pages after the current page
  func preloadPages() async {
    let preloadBefore = max(0, currentPage - 2)
    let preloadAfter = min(currentPage + 4, pages.count)
    let pagesToPreload = Array(preloadBefore..<preloadAfter)

    // Load pages concurrently for better performance
    await withTaskGroup(of: Void.self) { group in
      for index in pagesToPreload {
        // Only preload if not already cached
        if !pageImageCache.hasImage(forKey: index, bookId: bookId) {
          group.addTask {
            _ = await self.getPageImageFileURL(pageIndex: index)
          }
        }
      }
    }
  }

  /// Update reading progress on the server
  /// Uses API page number (1-based) instead of array index (0-based)
  func updateProgress() async {
    guard !bookId.isEmpty else { return }
    guard currentPage >= 0 && currentPage < pages.count else { return }

    let completed = currentPage >= pages.count - 1
    let apiPageNumber = pages[currentPage].number

    do {
      try await bookService.updateReadProgress(
        bookId: bookId,
        page: apiPageNumber,
        completed: completed
      )
    } catch {
      // Progress updates are non-critical, fail silently
    }
  }

  /// Convert display index to actual page index based on reading direction
  /// - Parameter displayIndex: The index as displayed to the user
  /// - Returns: The actual page index in the pages array
  func displayIndexToPageIndex(_ displayIndex: Int) -> Int {
    switch readingDirection {
    case .ltr:
      return displayIndex
    case .rtl:
      return pages.count - 1 - displayIndex
    case .vertical, .webtoon:
      return displayIndex
    }
  }

  /// Convert actual page index to display index based on reading direction
  /// - Parameter pageIndex: The actual page index in the pages array
  /// - Returns: The index as displayed to the user
  func pageIndexToDisplayIndex(_ pageIndex: Int) -> Int {
    switch readingDirection {
    case .ltr:
      return pageIndex
    case .rtl:
      return pages.count - 1 - pageIndex
    case .vertical, .webtoon:
      return pageIndex
    }
  }

  /// Save page image to Photos from cache
  /// - Parameter pageIndex: Zero-based page index
  /// - Returns: Result indicating success or failure with error message
  func savePageImageToPhotos(pageIndex: Int) async -> Result<Void, SaveImageError> {
    guard pageIndex >= 0 && pageIndex < pages.count else {
      return .failure(.invalidPageIndex)
    }

    guard !bookId.isEmpty else {
      return .failure(.bookIdEmpty)
    }

    // Get cached image file URL
    guard let imageURL = getCachedImageFileURL(pageIndex: pageIndex) else {
      return .failure(.imageNotCached)
    }

    // Check photo library authorization
    let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
    guard status == .authorized || status == .limited else {
      return .failure(.photoLibraryAccessDenied)
    }

    // Check image format
    guard let imageFormat = detectImageFormat(at: imageURL) else {
      return .failure(.unsupportedImageFormat)
    }

    // Check if format is supported by Photos library
    // Photos library supports: JPEG, PNG, HEIF, but not WebP
    if !isFormatSupportedByPhotos(format: imageFormat) {
      return .failure(.unsupportedImageFormat)
    }

    // Save to photo library directly from file URL (more efficient)
    do {
      try await PHPhotoLibrary.shared().performChanges {
        PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: imageURL)
      }
      return .success(())
    } catch {
      return .failure(.saveError(error.localizedDescription))
    }
  }

  // Detect image format from file URL
  private func detectImageFormat(at fileURL: URL) -> String? {
    // Read a small portion of the file to check format (more efficient than loading entire file)
    guard let fileHandle = try? FileHandle(forReadingFrom: fileURL),
      let imageData = try? fileHandle.read(upToCount: 12)
    else {
      return nil
    }
    defer {
      try? fileHandle.close()
    }

    guard imageData.count >= 12 else { return nil }

    // Check file signatures (magic numbers)
    let bytes = [UInt8](imageData.prefix(12))

    // JPEG: FF D8 FF
    if bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF {
      return "JPEG"
    }

    // PNG: 89 50 4E 47 0D 0A 1A 0A
    if bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47 {
      return "PNG"
    }

    // WebP: RIFF ... WEBP
    if bytes[0] == 0x52 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x46 {
      if bytes[8] == 0x57 && bytes[9] == 0x45 && bytes[10] == 0x42 && bytes[11] == 0x50 {
        return "WebP"
      }
    }

    // HEIF: ftyp ... mif1 or msf1
    if bytes[4] == 0x66 && bytes[5] == 0x74 && bytes[6] == 0x79 && bytes[7] == 0x70 {
      // Check for HEIF variants
      let heifTypes = ["mif1", "msf1", "heic", "heif"]
      let typeString = String(bytes: Array(bytes[8...11]), encoding: .ascii) ?? ""
      if heifTypes.contains(where: { typeString.lowercased().contains($0) }) {
        return "HEIF"
      }
    }

    return nil
  }

  // Check if image format is supported by Photos library
  private func isFormatSupportedByPhotos(format: String) -> Bool {
    let supportedFormats = ["JPEG", "PNG", "HEIF"]
    return supportedFormats.contains(format)
  }
}

enum SaveImageError: Error, LocalizedError {
  case invalidPageIndex
  case bookIdEmpty
  case imageNotCached
  case photoLibraryAccessDenied
  case failedToLoadImageData
  case unsupportedImageFormat
  case saveError(String)

  var errorDescription: String? {
    switch self {
    case .invalidPageIndex:
      return "Invalid page index"
    case .bookIdEmpty:
      return "Book ID is empty"
    case .imageNotCached:
      return "Image not cached yet"
    case .photoLibraryAccessDenied:
      return "Photo library access denied"
    case .failedToLoadImageData:
      return "Failed to load image data"
    case .unsupportedImageFormat:
      return "Image format not supported. Only JPEG, PNG, and HEIF formats can be saved to Photos."
    case .saveError(let message):
      return message
    }
  }
}
