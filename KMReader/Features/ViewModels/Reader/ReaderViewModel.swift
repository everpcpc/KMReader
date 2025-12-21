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
import UniformTypeIdentifiers

struct PagePair: Hashable {
  let first: Int
  let second: Int?
  var id: Int { first }

  func display(readingDirection: ReadingDirection) -> String {
    guard let second = second else {
      return "\(first + 1)"
    }
    // For RTL reading direction, first page is on the right, so display second,first
    // For LTR reading direction, first page is on the left, so display first,second
    if readingDirection == .rtl {
      return "\(second + 1),\(first + 1)"
    } else {
      return "\(first + 1),\(second + 1)"
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
  var tableOfContents: [ReaderTOCEntry] = []
  private var dualPageNoCoverEnabled: Bool
  private var forceDualPagePairs: Bool

  private let logger = AppLogger(.reader)
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

  convenience init() {
    self.init(
      dualPageNoCover: AppConfig.dualPageNoCover,
      pageLayout: AppConfig.pageLayout
    )
  }

  init(dualPageNoCover: Bool, pageLayout: PageLayout) {
    self.pageImageCache = ImageCache()
    self.dualPageNoCoverEnabled = dualPageNoCover
    self.forceDualPagePairs = pageLayout == .dual
    regenerateDualPageState()
  }

  func loadPages(book: Book, initialPageNumber: Int? = nil) async {
    self.bookId = book.id
    isLoading = true

    // Cancel all ongoing download tasks when loading a new book
    for (_, task) in downloadingTasks {
      task.cancel()
    }
    downloadingTasks.removeAll()

    do {
      let fetchedPages: [BookPage]
      if let localPages = await DatabaseOperator.shared.fetchPages(id: book.id) {
        fetchedPages = localPages
      } else if !AppConfig.isOffline {
        fetchedPages = try await BookService.shared.getBookPages(id: book.id)
        await DatabaseOperator.shared.updateBookPages(bookId: book.id, pages: fetchedPages)
      } else {
        throw APIError.offline
      }

      // Set initial page index BEFORE assigning pages to ensure proper scroll synchronization
      // This prevents race condition where pages.count changes but currentPageIndex is still 0
      if let initialPageNumber = initialPageNumber,
        let pageIndex = fetchedPages.firstIndex(where: { $0.number == initialPageNumber })
      {
        currentPageIndex = pageIndex
      }

      // Now assign pages, which will trigger View's onChange(of: pages.count)
      pages = fetchedPages

      // Update page pairs and dual page indices after loading pages
      regenerateDualPageState()

      // For EPUB, fetch manifest and parse TOC
      if book.media.mediaProfile == .epub {
        if let localTOC = await DatabaseOperator.shared.fetchTOC(id: book.id) {
          tableOfContents = localTOC
        } else if !AppConfig.isOffline {
          let manifest = try await BookService.shared.getBookManifest(id: book.id)
          let toc = await ReaderManifestService(
            bookId: book.id
          ).parseTOC(manifest: manifest)
          tableOfContents = toc
          await DatabaseOperator.shared.updateBookTOC(bookId: book.id, toc: toc)
        } else {
          tableOfContents = []
        }
      } else {
        tableOfContents = []
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

    // 1. Check OfflineManager (Persistent Offline Content)
    let ext = page.detectedUTType?.preferredFilenameExtension ?? "jpg"
    if let offlineURL = await OfflineManager.shared.getOfflinePageImageURL(
      instanceId: AppConfig.currentInstanceId, bookId: bookId, pageNumber: page.number,
      fileExtension: ext
    ) {
      logger.debug(
        "✅ Using offline downloaded image for page \(page.number) for book \(self.bookId)")
      return offlineURL
    }

    // 2. Check ImageCache (Transient Cache)
    if let cachedFileURL = await getCachedImageFileURL(page: page) {
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
      if let cachedFileURL = await getCachedImageFileURL(page: page) {
        return cachedFileURL
      }
      return nil
    }

    let downloadTask = Task<URL?, Never> {
      logger.info("📥 Downloading page \(page.number) for book \(self.bookId)")

      do {
        guard let remoteURL = self.resolvedDownloadURL(for: page) else {
          self.logger.error(
            "❌ Unable to resolve download URL for page \(page.number) in book \(self.bookId)")
          return nil
        }

        let activePage = self.pages.first(where: { $0.number == page.number }) ?? page

        let result = try await BookService.shared.downloadImageResource(at: remoteURL)
        let data = result.data

        let dataSize = ByteCountFormatter.string(
          fromByteCount: Int64(data.count), countStyle: .binary)
        logger.info(
          "✅ Downloaded page \(page.number) successfully (\(dataSize)) for book \(self.bookId)")

        await pageImageCache.storeImageData(
          data,
          bookId: self.bookId,
          page: activePage
        )

        if let fileURL = await getCachedImageFileURL(page: activePage) {
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
  func getCachedImageFileURL(page: BookPage) async -> URL? {
    guard !bookId.isEmpty else {
      return nil
    }

    // Use async check to avoid blocking main thread
    if await pageImageCache.hasImage(bookId: bookId, page: page) {
      return pageImageCache.imageFileURL(bookId: bookId, page: page)
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
        let hasImage = await pageImageCache.hasImage(bookId: bookId, page: page)
        if !hasImage {
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

    let activeBookId = bookId
    let currentPageNumber = currentPage.number
    let completed = currentPageIndex >= pages.count - 1

    Task.detached(priority: .utility) {
      do {
        if AppConfig.isOffline {
          await OfflineManager.shared.updateLocalProgress(
            bookId: activeBookId,
            page: currentPageNumber,
            completed: completed
          )
        } else {
          try await BookService.shared.updatePageReadProgress(
            bookId: activeBookId,
            page: currentPageNumber,
            completed: completed
          )
        }
      } catch {
        // Progress updates are non-critical, fail silently
        AppLogger(.reader).error(
          "Failed to update page progress for book \(activeBookId) page \(currentPageNumber): \(error.localizedDescription)"
        )
      }
    }
  }

  private func resolvedDownloadURL(for page: BookPage) -> URL? {
    if let url = page.downloadURL {
      return url
    }
    // Fallback: construct URL from page number
    return BookService.shared.getBookPageURL(bookId: bookId, page: page.number)
  }

  func updateDualPageSettings(noCover: Bool) {
    guard dualPageNoCoverEnabled != noCover else { return }
    dualPageNoCoverEnabled = noCover
    regenerateDualPageState()
  }

  func updatePageLayout(_ layout: PageLayout) {
    let shouldForceDualPage = layout == .dual
    guard forceDualPagePairs != shouldForceDualPage else { return }
    forceDualPagePairs = shouldForceDualPage
    regenerateDualPageState()
  }

  private func regenerateDualPageState() {
    pagePairs = generatePagePairs(
      pages: pages,
      noCover: dualPageNoCoverEnabled,
      forceDualPairs: forceDualPagePairs
    )
    dualPageIndices = generateDualPageIndices(pairs: pagePairs)
  }

  /// Save page image to Photos from cache
  /// - Parameter page: Book page to save
  /// - Returns: Result indicating success or failure with error message
  func savePageImageToPhotos(page: BookPage) async -> Result<Void, AppErrorType> {
    guard !bookId.isEmpty else {
      return .failure(.bookIdEmpty)
    }

    guard let fileURL = await getCachedImageFileURL(page: page) else {
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
        return .failure(.saveImageError(error.localizedDescription))
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
      return .failure(.saveImageError(error.localizedDescription))
    }
  }

  /// Load image using SDWebImage
  /// - Parameter fileURL: Local file URL
  /// - Returns: PlatformImage if successfully loaded, nil otherwise
  private func loadImageWithSDWebImage(from fileURL: URL) async -> PlatformImage? {
    #if os(iOS)
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
            {
              continuation.resume(returning: image)
            } else {
              continuation.resume(returning: nil)
            }
          }
        }
      }
    #elseif os(macOS)
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

private func generatePagePairs(
  pages: [BookPage],
  noCover: Bool,
  forceDualPairs: Bool
) -> [PagePair] {
  guard pages.count > 0 else { return [] }

  var pairs: [PagePair] = []

  var index = 0
  while index < pages.count {
    if forceDualPairs {
      let shouldShowSingle = (!noCover && index == 0) || index == pages.count - 1
      if shouldShowSingle {
        pairs.append(PagePair(first: index, second: nil))
        index += 1
      } else {
        let nextIndex = index + 1
        pairs.append(PagePair(first: index, second: nextIndex))
        index += 2
      }
      continue
    }

    let currentPage = pages[index]

    var useSinglePage = false
    if !currentPage.isPortrait {
      useSinglePage = true
    }
    if !noCover && index == 0 {
      useSinglePage = true
    }
    if index == pages.count - 1 {
      useSinglePage = true
    }

    if useSinglePage {
      pairs.append(PagePair(first: index, second: nil))
      index += 1
    } else {
      let nextPage = pages[index + 1]
      if nextPage.isPortrait {
        pairs.append(PagePair(first: index, second: index + 1))
        index += 2
      } else {
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
