//
//  ReaderViewModel.swift
//  Komga
//
//  Created by Komga iOS Client
//

import Foundation
import OSLog
import Photos
import SwiftUI
import UniformTypeIdentifiers

@MainActor
@Observable
class ReaderViewModel {
  var pages: [BookPage] = []
  var isolatePages: [Int] = []
  var currentPageIndex = 0
  var currentViewItemIndex = 0  // Index in viewItems array
  var targetPageIndex: Int? = nil
  var targetViewItemIndex: Int? = nil  // Target index in viewItems array navigation
  var isLoading = true
  var isDismissing = false
  var pageImageCache: ImageCache
  var incognitoMode: Bool = false
  var isZoomed: Bool = false

  var viewItems: [ReaderViewItem] = []
  var viewItemIndexByPage: [Int: Int] = [:]
  var tableOfContents: [ReaderTOCEntry] = []
  /// Cache of preloaded images keyed by page number for instant display
  var preloadedImages: [Int: PlatformImage] = [:]
  /// Page index with Live Text mode active (nil = no Live Text active)
  var liveTextActivePageIndex: Int? = nil
  private var isolateCoverPageEnabled: Bool
  private var forceDualPagePairs: Bool
  private var splitWidePageMode: SplitWidePageMode
  private var isActuallyUsingDualPageMode: Bool = false

  private let logger = AppLogger(.reader)
  /// Current book ID for API calls and cache access
  var bookId: String = ""

  /// Track ongoing download tasks to prevent duplicate downloads for the same page (keyed by page number)
  private var downloadingTasks: [Int: Task<URL?, Never>] = [:]
  private let progressDebounceIntervalSeconds: Int = 3
  private var lastPreloadRequestTime: Date?
  private var preloadTask: Task<Void, Never>?

  var currentPage: BookPage? {
    guard currentPageIndex >= 0 else { return nil }
    guard !pages.isEmpty else { return nil }
    let clampedIndex = min(currentPageIndex, pages.count - 1)
    return pages[clampedIndex]
  }

  var isCurrentPageIsolated: Bool {
    isolatePages.contains(currentPageIndex)
  }

  convenience init() {
    self.init(
      isolateCoverPage: AppConfig.isolateCoverPage,
      pageLayout: AppConfig.pageLayout,
      splitWidePageMode: AppConfig.splitWidePageMode
    )
  }

  init(isolateCoverPage: Bool, pageLayout: PageLayout, splitWidePageMode: SplitWidePageMode = .none) {
    self.pageImageCache = ImageCache()
    self.isolateCoverPageEnabled = isolateCoverPage
    self.forceDualPagePairs = pageLayout == .dual
    self.splitWidePageMode = splitWidePageMode
    regenerateViewState()
  }

  func loadPages(book: Book, initialPageNumber: Int? = nil) async {
    self.bookId = book.id
    isLoading = true

    // Cancel all ongoing download tasks when loading a new book
    for (_, task) in downloadingTasks {
      task.cancel()
    }
    downloadingTasks.removeAll()
    preloadedImages.removeAll()

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

      if let localIsolatePages = await DatabaseOperator.shared.fetchIsolatePages(id: book.id) {
        isolatePages = localIsolatePages
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
      regenerateViewState()

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
      instanceId: AppConfig.current.instanceId, bookId: bookId, pageNumber: page.number,
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
  /// Preloads a small window around the current page to keep memory usage in check
  func preloadPages() async {
    let now = Date()
    if let last = lastPreloadRequestTime,
      now.timeIntervalSince(last) < 0.3
    {
      return
    }
    lastPreloadRequestTime = now
    guard !bookId.isEmpty else { return }

    // Cancel any previous preloading task
    preloadTask?.cancel()

    let preloadBefore = max(0, currentPageIndex - ReaderConstants.preloadBefore)
    let preloadAfter = min(currentPageIndex + ReaderConstants.preloadAfter, pages.count)
    let pagesToPreload = Array(preloadBefore..<preloadAfter)

    preloadTask = Task { [weak self] in
      guard let self = self else { return }

      // Load pages concurrently and collect decoded images
      let results = await withTaskGroup(of: (Int, PlatformImage?).self) {
        group -> [(Int, PlatformImage?)] in
        for index in pagesToPreload {
          if Task.isCancelled { break }
          let page = self.pages[index]
          // Skip if already preloaded
          if self.preloadedImages[index] != nil {
            continue
          }
          group.addTask {
            if Task.isCancelled { return (index, nil) }
            // Get file URL (downloads if needed)
            guard let fileURL = await self.getPageImageFileURL(page: page) else {
              return (index, nil)
            }
            if Task.isCancelled { return (index, nil) }
            // Decode image from file
            let image = await self.loadImageFromFile(fileURL: fileURL)
            return (index, image)
          }
        }
        var collected: [(Int, PlatformImage?)] = []
        for await result in group {
          if !Task.isCancelled {
            collected.append(result)
          }
        }
        return collected
      }

      if Task.isCancelled { return }

      // Store preloaded images for instant access by PageImageView
      for (pageIndex, image) in results {
        if let image = image {
          self.preloadedImages[pageIndex] = image
        }
      }

      // Clean up images too far from current page to release memory
      self.cleanupDistantImagesAroundCurrentPage()
    }
  }

  /// Remove preloaded images that are too far from current page to release memory
  func cleanupDistantImagesAroundCurrentPage() {
    guard !pages.isEmpty else { return }
    let keepRangeStart = max(0, currentPageIndex - ReaderConstants.keepRangeBefore)
    let keepRangeEnd = min(currentPageIndex + ReaderConstants.keepRangeAfter, pages.count)
    let keepRange = keepRangeStart...keepRangeEnd

    let keysToRemove = preloadedImages.keys.filter { !keepRange.contains($0) }
    if !keysToRemove.isEmpty {
      for key in keysToRemove {
        preloadedImages.removeValue(forKey: key)
      }
    }

    // Log current memory usage
    let count = preloadedImages.count
    var totalBytes: Int64 = 0
    for image in preloadedImages.values {
      let size = image.size
      // Rough estimation: width * height * 4 bytes per pixel (RGBA)
      totalBytes += Int64(size.width * size.height * 4)
    }
    let mb = Double(totalBytes) / 1024 / 1024
    logger.debug(
      String(format: "🖼️ Memory Cache: %d images, approx. %.2f MB", count, mb)
    )
  }

  /// Load and decode image from file URL
  private func loadImageFromFile(fileURL: URL) async -> PlatformImage? {
    #if os(macOS)
      guard let image = NSImage(contentsOf: fileURL) else {
        return nil
      }
    #else
      guard let image = UIImage(contentsOfFile: fileURL.path) else {
        return nil
      }
    #endif

    return await ImageDecodeHelper.decodeForDisplay(image)
  }

  /// Preload a single page image into memory for instant display.
  func preloadImageForPage(_ page: BookPage) async -> PlatformImage? {
    guard let index = pages.firstIndex(where: { $0.number == page.number }) else { return nil }
    if let cached = preloadedImages[index] {
      return cached
    }
    guard let fileURL = await getPageImageFileURL(page: page) else { return nil }
    guard let image = await loadImageFromFile(fileURL: fileURL) else { return nil }
    preloadedImages[index] = image
    return image
  }

  /// Cancel any ongoing preloading tasks and clear preloaded images
  func clearPreloadedImages() {
    preloadTask?.cancel()
    preloadTask = nil
    preloadedImages.removeAll()
    logger.debug("🗑️ Cleared all preloaded images and cancelled tasks")
  }

  /// Update reading progress on the server
  /// Uses API page number (1-based) instead of array index (0-based)
  /// Skip update if incognito mode is enabled
  func updateProgress() async {
    // Skip progress updates in incognito mode
    guard !incognitoMode else {
      logger.debug("⏭️ Skip progress capture because incognito mode is enabled")
      return
    }
    guard !bookId.isEmpty else {
      logger.warning("⚠️ Skip progress capture because book ID is empty")
      return
    }
    guard let currentPage = currentPage else {
      logger.debug("⏭️ Skip progress capture because current page is unavailable")
      return
    }

    let completed = currentPageIndex >= pages.count - 1
    logger.debug(
      "📝 Captured pending page progress for book \(bookId): page=\(currentPage.number), completed=\(completed)"
    )

    await ReaderProgressDispatchService.shared.submitPageProgress(
      bookId: bookId,
      page: currentPage.number,
      completed: completed,
      debounceSeconds: progressDebounceIntervalSeconds
    )
  }

  func flushProgress() {
    guard !incognitoMode else {
      logger.debug("⏭️ Skip flush progress because incognito mode is enabled")
      return
    }

    let snapshotPage = currentPage?.number
    let snapshotCompleted =
      currentPage != nil
      ? (currentPageIndex >= pages.count - 1)
      : nil

    logger.debug(
      "🚿 Flush progress requested for book \(bookId): hasCurrentPage=\(snapshotPage != nil)"
    )

    Task {
      await ReaderProgressDispatchService.shared.flushPageProgress(
        bookId: bookId,
        snapshotPage: snapshotPage,
        snapshotCompleted: snapshotCompleted
      )
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
    let newIsolateCover = !noCover
    guard isolateCoverPageEnabled != newIsolateCover else { return }
    isolateCoverPageEnabled = newIsolateCover
    regenerateViewState()
  }

  func updatePageLayout(_ layout: PageLayout) {
    let shouldForceDualPage = layout == .dual
    guard forceDualPagePairs != shouldForceDualPage else { return }
    forceDualPagePairs = shouldForceDualPage
    regenerateViewState()
  }

  func updateSplitWidePageMode(_ mode: SplitWidePageMode) {
    guard splitWidePageMode != mode else { return }

    // currentPageIndex stores the actual page number in split mode
    let actualPageNumber = min(currentPageIndex, pages.count - 1)

    splitWidePageMode = mode
    regenerateViewState()

    // Set targetPageIndex to the actual page number (not viewItems index)
    // handleTargetPageChange will convert it to the correct viewItems index
    targetPageIndex = actualPageNumber
  }

  func updateActualDualPageMode(_ isUsing: Bool) {
    guard isActuallyUsingDualPageMode != isUsing else { return }
    isActuallyUsingDualPageMode = isUsing
    regenerateViewState()
  }

  func toggleIsolatePage(_ pageIndex: Int) {
    if let index = isolatePages.firstIndex(of: pageIndex) {
      isolatePages.remove(at: index)
    } else {
      isolatePages.append(pageIndex)
    }
    regenerateViewState()
    Task {
      await DatabaseOperator.shared.updateIsolatePages(bookId: bookId, pages: isolatePages)
      await DatabaseOperator.shared.commit()
    }
  }

  private func regenerateViewState() {
    // In actual dual page mode, disable split wide pages
    let effectiveSplitWidePages = splitWidePageMode.isEnabled && !isActuallyUsingDualPageMode

    // Cover page isolation only applies when NOT in single page mode
    // In single page mode, every page is already isolated
    let shouldIsolateCover = isolateCoverPageEnabled && (forceDualPagePairs || isActuallyUsingDualPageMode)

    viewItems = generateViewItems(
      pages: pages,
      noCover: !shouldIsolateCover,
      allowDualPairs: isActuallyUsingDualPageMode,
      forceDualPairs: forceDualPagePairs,
      splitWidePages: effectiveSplitWidePages,
      isolatePages: Set(isolatePages)
    )
    viewItemIndexByPage = generateViewItemIndexMap(items: viewItems)
    if !viewItems.isEmpty {
      currentViewItemIndex = viewItemIndex(forPageIndex: currentPageIndex)
    } else {
      currentViewItemIndex = 0
    }
  }

  func viewItem(at index: Int) -> ReaderViewItem? {
    guard index >= 0 && index < viewItems.count else { return nil }
    return viewItems[index]
  }

  func viewItemIndex(forPageIndex pageIndex: Int) -> Int {
    guard !viewItems.isEmpty else { return 0 }
    if pageIndex >= pages.count {
      return viewItems.count - 1
    }
    if pageIndex < 0 {
      return 0
    }
    if let mapped = viewItemIndexByPage[pageIndex] {
      return mapped
    }
    return min(pageIndex, viewItems.count - 1)
  }

  func pageIndex(forViewItemIndex viewItemIndex: Int) -> Int {
    guard let item = viewItem(at: viewItemIndex) else {
      return max(0, min(viewItemIndex, pages.count))
    }
    switch item {
    case .page(let index):
      return index
    case .split(let index, _):
      return index
    case .dual(let first, _):
      return first
    case .end:
      return pages.count
    }
  }

  func updateCurrentPosition(viewItemIndex: Int) {
    currentViewItemIndex = viewItemIndex
    currentPageIndex = pageIndex(forViewItemIndex: viewItemIndex)
  }

  func currentViewItem() -> ReaderViewItem? {
    if let item = viewItem(at: currentViewItemIndex) {
      return item
    }
    let fallbackIndex = viewItemIndex(forPageIndex: currentPageIndex)
    return viewItem(at: fallbackIndex)
  }

  func currentPagePair() -> (first: Int, second: Int?)? {
    guard let item = currentViewItem() else { return nil }
    switch item {
    case .page(let index):
      return (first: index, second: nil)
    case .split(let index, _):
      return (first: index, second: nil)
    case .dual(let first, let second):
      return (first: first, second: second)
    case .end:
      return nil
    }
  }

  func isLeftSplitHalf(
    isFirstHalf: Bool,
    readingDirection: ReadingDirection,
    splitWidePageMode: SplitWidePageMode
  ) -> Bool {
    let effectiveDirection = splitWidePageMode.effectiveReadingDirection(for: readingDirection)
    let shouldShowLeftFirst = effectiveDirection != .rtl
    return shouldShowLeftFirst ? isFirstHalf : !isFirstHalf
  }
}

private func generateViewItems(
  pages: [BookPage],
  noCover: Bool,
  allowDualPairs: Bool,
  forceDualPairs: Bool,
  splitWidePages: Bool,
  isolatePages: Set<Int> = []
) -> [ReaderViewItem] {
  guard pages.count > 0 else { return [] }

  var items: [ReaderViewItem] = []
  let shouldForceDualPairs = allowDualPairs && forceDualPairs

  var index = 0
  while index < pages.count {
    if shouldForceDualPairs {
      let shouldShowSingle =
        (!noCover && index == 0) || index == pages.count - 1
        || isolatePages.contains(index) || isolatePages.contains(index + 1)
      if shouldShowSingle {
        items.append(.page(index: index))
        index += 1
      } else {
        let nextIndex = index + 1
        items.append(.dual(first: index, second: nextIndex))
        index += 2
      }
      continue
    }

    let currentPage = pages[index]

    var useSinglePage = false
    var shouldSplitPage = false

    // Check if wide page should be split (only if not already isolated or cover)
    let isWidePageEligibleForSplit =
      !currentPage.isPortrait
      && splitWidePages
      && !isolatePages.contains(index)
      && (noCover || index != 0)  // Don't split cover page

    if isWidePageEligibleForSplit {
      shouldSplitPage = true
    }

    // Determine if page should be shown as single (without splitting)
    if !currentPage.isPortrait && !shouldSplitPage {
      useSinglePage = true
    }
    if !noCover && index == 0 {
      useSinglePage = true
      shouldSplitPage = false  // Ensure cover page is not split
    }
    if isolatePages.contains(index) {
      useSinglePage = true
      shouldSplitPage = false  // Ensure isolated pages are not split
    }
    if index == pages.count - 1 {
      useSinglePage = true
    }

    if shouldSplitPage {
      // Split the wide page into two items
      items.append(.split(index: index, isFirstHalf: true))
      items.append(.split(index: index, isFirstHalf: false))
      index += 1
    } else if useSinglePage {
      items.append(.page(index: index))
      index += 1
    } else {
      let nextPage = pages[index + 1]
      if allowDualPairs && nextPage.isPortrait && !isolatePages.contains(index + 1) {
        items.append(.dual(first: index, second: index + 1))
        index += 2
      } else {
        items.append(.page(index: index))
        index += 1
      }
    }
  }
  // insert end page item at the end
  items.append(.end)

  return items
}

private func generateViewItemIndexMap(items: [ReaderViewItem]) -> [Int: Int] {
  var indices: [Int: Int] = [:]
  for (index, item) in items.enumerated() {
    switch item {
    case .dual(let first, let second):
      if indices[first] == nil {
        indices[first] = index
      }
      if indices[second] == nil {
        indices[second] = index
      }
    default:
      guard let pageIndex = item.primaryPageIndex else { continue }
      if indices[pageIndex] == nil {
        indices[pageIndex] = index
      }
    }
  }
  return indices
}
