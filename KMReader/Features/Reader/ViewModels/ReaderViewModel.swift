//
// ReaderViewModel.swift
//
//

import Foundation
import ImageIO
import OSLog
import Photos
import SwiftUI
import UniformTypeIdentifiers

#if os(macOS)
  import AppKit
#endif

@MainActor
@Observable
class ReaderViewModel {
  var readerPages: [ReaderPage] = []
  private(set) var segments: [ReaderSegment] = []
  var isolatePages: [Int] = []
  private var isolatePagesByBookId: [String: Set<Int>] = [:]
  private var currentPageID: ReaderPageID?
  private var currentViewItemID: ReaderViewItem?
  var navigationTarget: ReaderViewItem?
  var isLoading = true
  var isDismissing = false
  var pageImageCache: ImageCache
  var incognitoMode: Bool = false
  var isZoomed: Bool = false

  var viewItems: [ReaderViewItem] = []
  var viewItemIndexByPage: [ReaderPageID: Int] = [:]
  var tableOfContents: [ReaderTOCEntry] = []
  private var tableOfContentsByBookId: [String: [ReaderTOCEntry]] = [:]
  private var tableOfContentsBookId: String?
  /// Cache of preloaded images keyed by reader page ID.
  private var preloadedImagesByID: [ReaderPageID: PlatformImage] = [:]
  /// Page index with Live Text mode active (nil = no Live Text active)
  var liveTextActivePageIndex: Int? = nil
  /// Confirmed animated image capability keyed by reader page ID.
  private var animatedPageStates: [ReaderPageID: Bool] = [:]
  /// Local file URL for animated page playback keyed by reader page ID.
  private var animatedPageFileURLs: [ReaderPageID: URL] = [:]
  private var isolateCoverPageEnabled: Bool
  private var forceDualPagePairs: Bool
  private var splitWidePageMode: SplitWidePageMode
  private var combineSplitWidePagePairInDualMode: Bool
  private var isActuallyUsingDualPageMode: Bool = false

  private let logger = AppLogger(.reader)
  private var bookMediaProfile: MediaProfile = .unknown

  /// Track ongoing download tasks to prevent duplicate downloads for the same page.
  private var downloadingTasks: [ReaderPageID: Task<URL?, Never>] = [:]
  private var upscalingTasks: [ReaderPageID: Task<URL?, Never>] = [:]
  private var readerPageIndexByID: [ReaderPageID: Int] = [:]
  private var segmentPageRangeByBookId: [String: Range<Int>] = [:]
  private(set) var readerPagesVersion: Int = 0
  private var lastPreloadRequestTime: Date?
  private var preloadTask: Task<Void, Never>?

  private var resolvedCurrentPageID: ReaderPageID? {
    if let currentPageID, readerPageIndexByID[currentPageID] != nil {
      return currentPageID
    }
    if let currentViewItemID,
      readerPageIndexByID[currentViewItemID.pageID] != nil
    {
      return currentViewItemID.pageID
    }
    return readerPages.first?.id
  }

  private var resolvedCurrentPageIndex: Int? {
    guard let resolvedCurrentPageID else { return nil }
    return readerPageIndexByID[resolvedCurrentPageID]
  }

  var currentPage: BookPage? {
    currentReaderPage?.page
  }

  var isShowingEndPage: Bool {
    currentViewItem()?.isEnd == true
  }

  var pageCount: Int {
    readerPages.count
  }

  var hasPages: Bool {
    !readerPages.isEmpty
  }

  var activeBookId: String? {
    currentReaderPage?.bookId ?? segments.first?.currentBook.id
  }

  var currentReaderPage: ReaderPage? {
    guard let resolvedCurrentPageIndex else { return nil }
    return readerPages[resolvedCurrentPageIndex]
  }

  var isCurrentPageIsolated: Bool {
    guard let currentReaderPage else { return false }
    guard let isolatePosition = isolatePosition(for: currentReaderPage.id) else { return false }
    return isolatePagesByBookId[currentReaderPage.bookId]?.contains(isolatePosition.localIndex) == true
  }

  convenience init() {
    self.init(
      isolateCoverPage: AppConfig.isolateCoverPage,
      pageLayout: AppConfig.pageLayout,
      splitWidePageMode: AppConfig.splitWidePageMode,
      incognitoMode: false
    )
  }

  init(
    isolateCoverPage: Bool,
    pageLayout: PageLayout,
    splitWidePageMode: SplitWidePageMode = .none,
    incognitoMode: Bool = false
  ) {
    self.pageImageCache = ImageCache()
    self.isolateCoverPageEnabled = isolateCoverPage
    self.forceDualPagePairs = pageLayout == .dual
    self.splitWidePageMode = splitWidePageMode
    self.combineSplitWidePagePairInDualMode = false
    self.incognitoMode = incognitoMode
    regenerateViewState()
  }

  private func rebuildReaderPages() {
    var flattenedReaderPages: [ReaderPage] = []
    var indexMap: [ReaderPageID: Int] = [:]
    var rangeByBookId: [String: Range<Int>] = [:]

    flattenedReaderPages.reserveCapacity(segments.reduce(0) { $0 + $1.pages.count })

    var globalIndex = 0
    for segment in segments {
      let segmentStart = globalIndex
      for page in segment.pages {
        let readerPage = ReaderPage(bookId: segment.currentBook.id, page: page)
        flattenedReaderPages.append(readerPage)
        indexMap[readerPage.id] = globalIndex
        globalIndex += 1
      }
      rangeByBookId[segment.currentBook.id] = segmentStart..<globalIndex
    }

    readerPages = flattenedReaderPages
    readerPageIndexByID = indexMap
    segmentPageRangeByBookId = rangeByBookId
    readerPagesVersion &+= 1
    rebuildIsolatePageIndices()
  }

  private func rebuildIsolatePageIndices() {
    var flattenedIndices: [Int] = []
    flattenedIndices.reserveCapacity(isolatePagesByBookId.values.reduce(0) { $0 + $1.count })

    for (globalIndex, readerPage) in readerPages.enumerated() {
      guard let range = segmentPageRangeByBookId[readerPage.bookId], range.contains(globalIndex) else {
        continue
      }
      let localIndex = globalIndex - range.lowerBound
      if isolatePagesByBookId[readerPage.bookId]?.contains(localIndex) == true {
        flattenedIndices.append(globalIndex)
      }
    }

    isolatePages = flattenedIndices
  }

  private func isolatePosition(forGlobalPageIndex pageIndex: Int) -> (bookId: String, localIndex: Int)? {
    guard let readerPage = readerPage(at: pageIndex),
      let range = segmentPageRangeByBookId[readerPage.bookId],
      range.contains(pageIndex)
    else {
      return nil
    }
    return (readerPage.bookId, pageIndex - range.lowerBound)
  }

  private func isolatePosition(for pageID: ReaderPageID) -> (bookId: String, localIndex: Int)? {
    guard let pageIndex = pageIndex(for: pageID) else { return nil }
    return isolatePosition(forGlobalPageIndex: pageIndex)
  }

  private func readerPageID(forPageIndex pageIndex: Int) -> ReaderPageID? {
    guard pageIndex >= 0, pageIndex < readerPages.count else { return nil }
    return readerPages[pageIndex].id
  }

  private func resolvedViewItem(
    preferredItem: ReaderViewItem? = nil,
    preferredPageID: ReaderPageID? = nil
  ) -> ReaderViewItem? {
    if let preferredItem, viewItemIndex(for: preferredItem) != nil {
      return preferredItem
    }
    if let preferredPageID, let resolvedItem = viewItem(for: preferredPageID) {
      return resolvedItem
    }
    if let preferredItem,
      let resolvedItem = viewItem(for: preferredItem.pageID)
    {
      return resolvedItem
    }
    return viewItems.first
  }

  func resolvedViewItem(for item: ReaderViewItem?) -> ReaderViewItem? {
    resolvedViewItem(
      preferredItem: item,
      preferredPageID: item?.pageID
    )
  }

  func preloadedImage(for pageID: ReaderPageID) -> PlatformImage? {
    preloadedImagesByID[pageID]
  }

  private func setPreloadedImage(_ image: PlatformImage, forPageIndex pageIndex: Int) {
    guard let pageID = readerPageID(forPageIndex: pageIndex) else { return }
    preloadedImagesByID[pageID] = image
  }

  private func readerPage(at pageIndex: Int) -> ReaderPage? {
    guard pageIndex >= 0, pageIndex < readerPages.count else { return nil }
    return readerPages[pageIndex]
  }

  func readerPage(for pageID: ReaderPageID) -> ReaderPage? {
    guard let pageIndex = pageIndex(for: pageID) else { return nil }
    return readerPage(at: pageIndex)
  }

  func page(for pageID: ReaderPageID) -> BookPage? {
    readerPage(for: pageID)?.page
  }

  private func pageWindowEntries(around pageID: ReaderPageID?, before: Int, after: Int)
    -> [(index: Int, pageID: ReaderPageID)]
  {
    guard let pageID, let centerIndex = pageIndex(for: pageID), !readerPages.isEmpty else { return [] }
    let safeBefore = max(before, 0)
    let safeAfter = max(after, 0)
    let upperBound = max(pageCount - 1, 0)
    let lowerIndex = max(centerIndex - safeBefore, 0)
    let upperIndex = min(centerIndex + safeAfter, upperBound)
    guard lowerIndex <= upperIndex else { return [] }
    return readerPages[lowerIndex...upperIndex].enumerated().map { offset, readerPage in
      (index: lowerIndex + offset, pageID: readerPage.id)
    }
  }

  func neighboringPageIDs(around pageID: ReaderPageID, radius: Int) -> [ReaderPageID] {
    pageWindowEntries(around: pageID, before: radius, after: radius).map(\.pageID)
  }

  func pageIndex(for readerPageID: ReaderPageID) -> Int? {
    readerPageIndexByID[readerPageID]
  }

  private func segmentIndex(forSegmentBookId bookId: String) -> Int? {
    segments.firstIndex(where: { $0.currentBook.id == bookId })
  }

  func nextBook(forSegmentBookId bookId: String) -> Book? {
    guard let segmentIndex = segmentIndex(forSegmentBookId: bookId) else { return nil }
    return segments[segmentIndex].nextBook
  }

  func currentBook(forSegmentBookId bookId: String) -> Book? {
    guard let segmentIndex = segmentIndex(forSegmentBookId: bookId) else { return nil }
    return segments[segmentIndex].currentBook
  }

  func previousBook(forSegmentBookId bookId: String) -> Book? {
    guard let segmentIndex = segmentIndex(forSegmentBookId: bookId) else { return nil }
    return segments[segmentIndex].previousBook
  }

  private func segmentPageRange(forSegmentBookId bookId: String) -> Range<Int>? {
    segmentPageRangeByBookId[bookId]
  }

  func segmentReaderPages(forSegmentBookId bookId: String) -> [ReaderPage] {
    guard let range = segmentPageRange(forSegmentBookId: bookId) else { return [] }
    return Array(readerPages[range])
  }

  func pageID(forSegmentBookId bookId: String, pageNumberInSegment pageNumber: Int) -> ReaderPageID? {
    guard let range = segmentPageRange(forSegmentBookId: bookId), !range.isEmpty else { return nil }
    let localIndex = pageNumber - 1
    guard localIndex >= 0 && localIndex < range.count else { return nil }
    return readerPages[range.lowerBound + localIndex].id
  }

  func lastPageID(forSegmentBookId bookId: String) -> ReaderPageID? {
    guard let range = segmentPageRange(forSegmentBookId: bookId), !range.isEmpty else { return nil }
    return readerPages[range.upperBound - 1].id
  }

  func pageCount(forSegmentBookId bookId: String) -> Int {
    segmentPageRange(forSegmentBookId: bookId)?.count ?? 0
  }

  func displayPageNumber(for pageID: ReaderPageID) -> Int? {
    guard let readerPage = readerPage(for: pageID) else { return nil }
    let offset = displayPageNumberOffset(forBookId: readerPage.bookId)
    return readerPage.page.number + offset
  }

  private func displayPageNumberOffset(forBookId bookId: String) -> Int {
    guard let range = segmentPageRangeByBookId[bookId],
      let firstPageNumber = readerPage(at: range.lowerBound)?.page.number
    else {
      return 1
    }
    return firstPageNumber == 0 ? 1 : 0
  }

  func activeSegmentContext(
    fallbackBookId: String,
    fallbackCurrentBook: Book?,
    fallbackPreviousBook: Book?,
    fallbackNextBook: Book?
  ) -> (bookId: String, currentBook: Book?, previousBook: Book?, nextBook: Book?) {
    let segmentBookId = currentReaderPage?.bookId ?? fallbackBookId
    let shouldUseFallback = segmentBookId == fallbackBookId

    let segmentCurrentBook = currentBook(forSegmentBookId: segmentBookId)
    let segmentPreviousBook = previousBook(forSegmentBookId: segmentBookId)
    let segmentNextBook = nextBook(forSegmentBookId: segmentBookId)

    return (
      bookId: segmentBookId,
      currentBook: segmentCurrentBook ?? (shouldUseFallback ? fallbackCurrentBook : nil),
      previousBook: segmentPreviousBook ?? (shouldUseFallback ? fallbackPreviousBook : nil),
      nextBook: segmentNextBook ?? (shouldUseFallback ? fallbackNextBook : nil)
    )
  }

  func currentPageNumber(inSegmentBookId bookId: String) -> Int? {
    guard let currentPageOffset = currentPageOffsetInSegment(for: bookId) else { return nil }
    return currentPageOffset + 1
  }

  func currentPageOffsetInSegment(for bookId: String) -> Int? {
    guard let currentReaderPage,
      currentReaderPage.bookId == bookId,
      let range = segmentPageRangeByBookId[bookId],
      let currentPageIndex = pageIndex(for: currentReaderPage.id),
      range.contains(currentPageIndex)
    else {
      return nil
    }
    return currentPageIndex - range.lowerBound
  }

  func remainingPagesInSegment(for bookId: String) -> Int? {
    guard let currentPageOffset = currentPageOffsetInSegment(for: bookId),
      let range = segmentPageRangeByBookId[bookId]
    else {
      return nil
    }
    return max(range.count - currentPageOffset - 1, 0)
  }

  func currentTOCSelection(in entries: [ReaderTOCEntry], for bookId: String) -> ReaderTOCSelection {
    guard let currentPageOffset = currentPageOffsetInSegment(for: bookId) else {
      return .empty
    }
    return ReaderTOCSelection.resolve(in: entries, currentPageIndex: currentPageOffset)
  }

  private func setTableOfContents(_ toc: [ReaderTOCEntry], for bookId: String) {
    tableOfContentsByBookId[bookId] = toc
    tableOfContents = toc
    tableOfContentsBookId = bookId
  }

  private func loadTableOfContentsFromStorageOrNetwork(for book: Book) async -> [ReaderTOCEntry] {
    let mediaProfile = book.media.mediaProfileValue ?? .unknown

    if mediaProfile == .epub {
      if let localTOC = await DatabaseOperator.shared.fetchTOC(id: book.id) {
        return localTOC
      }
      if !AppConfig.isOffline {
        do {
          let manifest = try await BookService.shared.getBookManifest(id: book.id)
          let toc = await ReaderManifestService(bookId: book.id).parseTOC(manifest: manifest)
          await DatabaseOperator.shared.updateBookTOC(bookId: book.id, toc: toc)
          return toc
        } catch {
          logger.error("❌ Failed to load TOC from manifest for book \(book.id): \(error)")
          return []
        }
      }
      return []
    }

    if mediaProfile == .pdf {
      return await DatabaseOperator.shared.fetchTOC(id: book.id) ?? []
    }

    return []
  }

  func ensureTableOfContentsLoaded(for book: Book) async {
    if let cachedTOC = tableOfContentsByBookId[book.id] {
      setTableOfContents(cachedTOC, for: book.id)
      return
    }

    let toc = await loadTableOfContentsFromStorageOrNetwork(for: book)
    setTableOfContents(toc, for: book.id)
  }

  func ensureTableOfContentsForCurrentSegment() async {
    guard let currentReaderPage else { return }
    let segmentBookId = currentReaderPage.bookId

    guard tableOfContentsBookId != segmentBookId else { return }
    guard let segmentBook = currentBook(forSegmentBookId: segmentBookId) else {
      tableOfContents = []
      tableOfContentsBookId = segmentBookId
      return
    }

    await ensureTableOfContentsLoaded(for: segmentBook)
  }

  private func setSegments(_ segments: [ReaderSegment]) {
    self.segments = segments
    rebuildReaderPages()
  }

  private func updateSegmentContext(
    forCurrentBookId currentBookId: String,
    previousBook: Book?,
    nextBook: Book?
  ) {
    guard let segmentIndex = segmentIndex(forSegmentBookId: currentBookId) else {
      return
    }
    let segment = segments[segmentIndex]
    segments[segmentIndex] = ReaderSegment(
      previousBook: previousBook,
      currentBook: segment.currentBook,
      nextBook: nextBook,
      pages: segment.pages
    )
  }

  private func appendSegment(
    currentBook: Book,
    previousBook: Book?,
    nextBook: Book?,
    pages: [BookPage]
  ) {
    segments.append(
      ReaderSegment(
        previousBook: previousBook,
        currentBook: currentBook,
        nextBook: nextBook,
        pages: pages
      ))
    rebuildReaderPages()
  }

  private func prependSegment(
    currentBook: Book,
    previousBook: Book?,
    nextBook: Book?,
    pages: [BookPage]
  ) {
    segments.insert(
      ReaderSegment(
        previousBook: previousBook,
        currentBook: currentBook,
        nextBook: nextBook,
        pages: pages
      ),
      at: 0
    )
    rebuildReaderPages()
  }

  private func fetchSegmentPages(for book: Book) async -> [BookPage]? {
    if let cachedPages = await DatabaseOperator.shared.fetchPages(id: book.id) {
      return cachedPages
    }

    guard !AppConfig.isOffline else {
      return nil
    }

    do {
      let fetchedPages = try await BookService.shared.getBookPages(id: book.id)
      await DatabaseOperator.shared.updateBookPages(bookId: book.id, pages: fetchedPages)
      return fetchedPages
    } catch {
      logger.error("❌ Failed to preload segment pages for book \(book.id): \(error)")
      return nil
    }
  }

  private func hydrateIsolatePages(for bookId: String) async {
    let isolatePagesForBook = await DatabaseOperator.shared.fetchIsolatePages(id: bookId) ?? []
    isolatePagesByBookId[bookId] = Set(isolatePagesForBook)
  }

  private func restoreCurrentPosition(using currentPageID: ReaderPageID?) {
    guard currentPageID != nil else { return }
    updateCurrentPosition(pageID: currentPageID)
  }

  private func resetStateForBookLoad() {
    preloadTask?.cancel()
    preloadTask = nil
    lastPreloadRequestTime = nil

    for (_, task) in downloadingTasks {
      task.cancel()
    }
    downloadingTasks.removeAll()
    for (_, task) in upscalingTasks {
      task.cancel()
    }
    upscalingTasks.removeAll()

    preloadedImagesByID.removeAll()
    isolatePages.removeAll()
    isolatePagesByBookId.removeAll()
    tableOfContents.removeAll()
    tableOfContentsByBookId.removeAll()
    tableOfContentsBookId = nil
    segments.removeAll()
    readerPages.removeAll()
    readerPageIndexByID.removeAll()
    segmentPageRangeByBookId.removeAll()
    animatedPageStates.removeAll()
    animatedPageFileURLs.removeAll()
    liveTextActivePageIndex = nil
    currentPageID = nil
    currentViewItemID = nil
    navigationTarget = nil
    readerPagesVersion &+= 1
  }

  func preloadNextSegmentIfNeeded(
    currentBook: Book,
    previousBook: Book?,
    nextBook: Book?
  ) async {
    updateSegmentContext(
      forCurrentBookId: currentBook.id,
      previousBook: previousBook,
      nextBook: nextBook
    )

    guard let nextBook else {
      regenerateViewState()
      return
    }
    guard !segments.contains(where: { $0.currentBook.id == nextBook.id }) else {
      regenerateViewState()
      return
    }

    let currentPageID = currentReaderPage?.id

    guard let fetchedPages = await fetchSegmentPages(for: nextBook) else {
      regenerateViewState()
      return
    }

    guard !fetchedPages.isEmpty else {
      regenerateViewState()
      return
    }

    await hydrateIsolatePages(for: nextBook.id)

    appendSegment(
      currentBook: nextBook,
      previousBook: currentBook,
      nextBook: nil,
      pages: fetchedPages
    )
    regenerateViewState()
    restoreCurrentPosition(using: currentPageID)
  }

  func preloadPreviousSegmentIfNeeded(
    currentBook: Book,
    previousBook: Book?,
    nextBook: Book?,
    previousPreviousBook: Book?
  ) async {
    updateSegmentContext(
      forCurrentBookId: currentBook.id,
      previousBook: previousBook,
      nextBook: nextBook
    )

    guard let previousBook else {
      regenerateViewState()
      return
    }
    guard !segments.contains(where: { $0.currentBook.id == previousBook.id }) else {
      regenerateViewState()
      return
    }

    let currentPageID = currentReaderPage?.id

    guard let fetchedPages = await fetchSegmentPages(for: previousBook) else {
      regenerateViewState()
      return
    }

    guard !fetchedPages.isEmpty else {
      regenerateViewState()
      return
    }

    await hydrateIsolatePages(for: previousBook.id)

    prependSegment(
      currentBook: previousBook,
      previousBook: previousPreviousBook,
      nextBook: currentBook,
      pages: fetchedPages
    )
    regenerateViewState()
    restoreCurrentPosition(using: currentPageID)
  }

  func loadPages(
    book: Book,
    initialPageNumber: Int? = nil,
    previousBook: Book? = nil,
    nextBook: Book? = nil
  ) async {
    self.bookMediaProfile = book.media.mediaProfileValue ?? .unknown
    isLoading = true

    resetStateForBookLoad()

    do {
      await prepareOfflinePDFForDivina(book: book)

      let fetchedPages: [BookPage]
      if let localPages = await DatabaseOperator.shared.fetchPages(id: book.id) {
        fetchedPages = localPages
      } else if !AppConfig.isOffline {
        fetchedPages = try await BookService.shared.getBookPages(id: book.id)
        await DatabaseOperator.shared.updateBookPages(bookId: book.id, pages: fetchedPages)
      } else {
        throw APIError.offline
      }

      let localIsolatePages = await DatabaseOperator.shared.fetchIsolatePages(id: book.id) ?? []
      isolatePagesByBookId[book.id] = Set(localIsolatePages)
      currentPageID = initialPageNumber.flatMap { pageNumber in
        fetchedPages.first(where: { $0.number == pageNumber }).map {
          ReaderPageID(bookId: book.id, pageNumber: $0.number)
        }
      }
      currentViewItemID = nil
      navigationTarget = nil

      setSegments([
        ReaderSegment(
          previousBook: previousBook,
          currentBook: book,
          nextBook: nextBook,
          pages: fetchedPages,
        )
      ])

      // Update page pairs and dual page indices after loading pages
      regenerateViewState()

      await ensureTableOfContentsLoaded(for: book)
    } catch {
      ErrorManager.shared.alert(error: error)
    }

    isLoading = false
  }

  /// Get page image file URL from disk cache, or download and cache if not available
  /// - Parameter pageIndex: Reader page index in the flattened segment stream
  /// - Returns: Local file URL if available, nil if download failed
  /// - Note: Prevents duplicate downloads by tracking ongoing tasks
  private func getPageImageFileURL(pageIndex: Int) async -> URL? {
    guard let readerPage = readerPage(at: pageIndex) else {
      logger.warning("⚠️ Invalid page index \(pageIndex), cannot load page image")
      return nil
    }

    let pageID = readerPage.id
    let page = readerPage.page
    let currentBookId = readerPage.bookId

    if let existingTask = downloadingTasks[pageID] {
      logger.debug(
        "⏳ Waiting for existing download task for page \(page.number) for book \(currentBookId)"
      )
      if let result = await existingTask.value {
        return result
      }
      if let cachedFileURL = await getCachedImageFileURL(for: readerPage) {
        return cachedFileURL
      }
      return nil
    }

    let loadTask = Task<URL?, Never> {
      let ext = page.detectedUTType?.preferredFilenameExtension ?? "jpg"
      if let offlineURL = await OfflineManager.shared.getOfflinePageImageURL(
        instanceId: AppConfig.current.instanceId,
        bookId: currentBookId,
        pageNumber: page.number,
        fileExtension: ext
      ) {
        self.logger.debug(
          "✅ Using offline downloaded image for page \(page.number) for book \(currentBookId)")
        return offlineURL
      }

      if let cachedFileURL = await self.getCachedImageFileURL(for: readerPage) {
        self.logger.debug("✅ Using cached image for page \(page.number) for book \(currentBookId)")
        return cachedFileURL
      }

      if AppConfig.isOffline {
        self.logger.error("❌ Missing offline page \(page.number) for book \(currentBookId)")
        return nil
      }

      self.logger.info("📥 Downloading page \(page.number) for book \(currentBookId)")

      do {
        guard let remoteURL = self.resolvedDownloadURL(for: page, bookId: currentBookId) else {
          self.logger.error(
            "❌ Unable to resolve download URL for page \(page.number) in book \(currentBookId)")
          return nil
        }

        let result = try await BookService.shared.downloadImageResource(at: remoteURL)
        let data = result.data

        let dataSize = ByteCountFormatter.string(
          fromByteCount: Int64(data.count), countStyle: .binary)
        logger.info(
          "✅ Downloaded page \(page.number) successfully (\(dataSize)) for book \(currentBookId)")

        await pageImageCache.storeImageData(
          data,
          bookId: currentBookId,
          page: page
        )

        if let fileURL = await getCachedImageFileURL(for: readerPage) {
          logger.debug("💾 Saved page \(page.number) to disk cache for book \(currentBookId)")
          return fileURL
        } else {
          logger.error(
            "❌ Failed to get file URL after saving page \(page.number) to cache for book \(currentBookId)"
          )
          return nil
        }
      } catch {
        logger.error(
          "❌ Failed to download page \(page.number) for book \(currentBookId): \(error)"
        )
        return nil
      }
    }

    downloadingTasks[pageID] = loadTask
    let result = await loadTask.value
    downloadingTasks.removeValue(forKey: pageID)
    return result
  }

  func getPageImageFileURL(pageID: ReaderPageID) async -> URL? {
    guard let pageIndex = pageIndex(for: pageID) else { return nil }
    return await getPageImageFileURL(pageIndex: pageIndex)
  }

  /// Get cached image file URL from disk cache for a specific reader page.
  private func getCachedImageFileURL(for readerPage: ReaderPage) async -> URL? {
    if await pageImageCache.hasImage(bookId: readerPage.bookId, page: readerPage.page) {
      return pageImageCache.imageFileURL(bookId: readerPage.bookId, page: readerPage.page)
    }
    return nil
  }

  private func prepareOfflinePDFForDivina(book: Book) async {
    guard bookMediaProfile == .pdf else {
      return
    }

    logger.debug("🧪 Preparing offline PDF metadata for Divina, book \(book.id)")

    guard
      let offlinePDFURL = await OfflineManager.shared.getOfflinePDFURL(
        instanceId: AppConfig.current.instanceId,
        bookId: book.id
      )
    else {
      logger.debug("⏭️ Skip offline PDF preparation because offline PDF file is missing for book \(book.id)")
      return
    }

    let hasLocalPages = !(await DatabaseOperator.shared.fetchPages(id: book.id)?.isEmpty ?? true)
    let hasLocalTOC = await DatabaseOperator.shared.fetchTOC(id: book.id) != nil
    let forceRebuildMetadata = !hasLocalPages || !hasLocalTOC
    if forceRebuildMetadata {
      logger.debug(
        "🛠️ Force PDF metadata rebuild for book \(book.id), hasPages=\(hasLocalPages), hasTOC=\(hasLocalTOC)"
      )
    }

    guard
      let result = await PdfOfflinePreparationService.shared.prepare(
        instanceId: AppConfig.current.instanceId,
        bookId: book.id,
        documentURL: offlinePDFURL,
        forceRebuildMetadata: forceRebuildMetadata
      )
    else {
      logger.debug("⏭️ Skip offline PDF preparation because assets are already valid for book \(book.id)")
      return
    }

    await applyPreparedPDFMetadata(bookId: book.id, result: result)
  }

  private func applyPreparedPDFMetadata(
    bookId: String,
    result: PdfOfflinePreparationService.PreparationResult
  ) async {
    logger.debug(
      "💾 Applying prepared PDF metadata to database for book \(bookId), pages=\(result.pages.count), toc=\(result.tableOfContents.count)"
    )

    await DatabaseOperator.shared.updateBookPages(bookId: bookId, pages: result.pages)
    await DatabaseOperator.shared.updateBookTOC(bookId: bookId, toc: result.tableOfContents)
    await DatabaseOperator.shared.commit()
    if result.renderedImageCount > 0 {
      await OfflineManager.shared.refreshDownloadedBookSize(
        instanceId: AppConfig.current.instanceId,
        bookId: bookId
      )
    } else {
      logger.debug("⏭️ Skip downloaded size refresh for book \(bookId) because no new PDF page was rendered")
    }

    logger.debug(
      "✅ Applied prepared PDF metadata for book \(bookId), rendered=\(result.renderedImageCount), reused=\(result.reusedImageCount), skipped=\(result.skippedImageCount)"
    )
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
    guard !readerPages.isEmpty else { return }

    // Cancel any previous preloading task
    preloadTask?.cancel()
    let pagesToPreload = pageWindowEntries(
      around: resolvedCurrentPageID,
      before: ReaderConstants.preloadBefore,
      after: ReaderConstants.preloadAfter - 1
    )
    guard !pagesToPreload.isEmpty else { return }

    preloadTask = Task { [weak self] in
      guard let self = self else { return }

      // Load pages concurrently and collect decoded images
      let results = await withTaskGroup(of: (Int, ReaderPageID, PlatformImage?, Bool, URL?).self) {
        group -> [(Int, ReaderPageID, PlatformImage?, Bool, URL?)] in
        for (index, pageID) in pagesToPreload {
          if Task.isCancelled { break }
          // Skip if already preloaded
          if self.preloadedImage(for: pageID) != nil {
            continue
          }
          group.addTask {
            if Task.isCancelled { return (index, pageID, nil, false, nil) }
            let (image, isAnimated, animatedFileURL) = await self.preloadDecodedPageImage(
              pageIndex: index
            )
            return (index, pageID, image, isAnimated, animatedFileURL)
          }
        }
        var collected: [(Int, ReaderPageID, PlatformImage?, Bool, URL?)] = []
        for await result in group {
          if !Task.isCancelled {
            collected.append(result)
          }
        }
        return collected
      }

      if Task.isCancelled { return }

      // Store preloaded images for instant access by PageImageView
      for (pageIndex, pageID, image, isAnimated, animatedFileURL) in results {
        self.animatedPageStates[pageID] = isAnimated
        if let animatedFileURL {
          self.animatedPageFileURLs[pageID] = animatedFileURL
        } else {
          self.animatedPageFileURLs.removeValue(forKey: pageID)
        }
        if let image = image {
          self.setPreloadedImage(image, forPageIndex: pageIndex)
        }
      }

      // Clean up images too far from current page to release memory
      self.cleanupDistantImagesAroundCurrentPage()
    }
  }

  /// Remove preloaded images that are too far from current page to release memory
  func cleanupDistantImagesAroundCurrentPage() {
    guard hasPages else { return }
    let keepPageIDs = Set(
      pageWindowEntries(
        around: resolvedCurrentPageID,
        before: ReaderConstants.keepRangeBefore,
        after: ReaderConstants.keepRangeAfter
      ).map(\.pageID)
    )
    if !keepPageIDs.isEmpty {
      let imageKeysToRemove = preloadedImagesByID.keys.filter { !keepPageIDs.contains($0) }
      if !imageKeysToRemove.isEmpty {
        for key in imageKeysToRemove {
          preloadedImagesByID.removeValue(forKey: key)
        }
      }

      let animatedStateKeysToRemove = animatedPageStates.keys.filter { !keepPageIDs.contains($0) }
      if !animatedStateKeysToRemove.isEmpty {
        for key in animatedStateKeysToRemove {
          animatedPageStates.removeValue(forKey: key)
        }
      }

      let animatedURLKeysToRemove = animatedPageFileURLs.keys.filter { !keepPageIDs.contains($0) }
      if !animatedURLKeysToRemove.isEmpty {
        for key in animatedURLKeysToRemove {
          animatedPageFileURLs.removeValue(forKey: key)
        }
      }
    }

    // Log current memory usage
    let count = preloadedImagesByID.count
    var totalBytes: Int64 = 0
    for image in preloadedImagesByID.values {
      let size = image.size
      // Rough estimation: width * height * 4 bytes per pixel (RGBA)
      totalBytes += Int64(size.width * size.height * 4)
    }
    let mb = Double(totalBytes) / 1024 / 1024
    logger.debug(
      String(format: "🖼️ Memory Cache: %d images, approx. %.2f MB", count, mb)
    )
  }

  nonisolated private static func detectAnimatedState(for page: BookPage, fileURL: URL) -> Bool {
    guard page.isAnimatedImageCandidate else {
      return false
    }
    return Self.isAnimatedImageFile(at: fileURL)
  }

  nonisolated private static func isAnimatedImageFile(at fileURL: URL) -> Bool {
    let options = [kCGImageSourceShouldCache: false] as CFDictionary
    guard let source = CGImageSourceCreateWithURL(fileURL as CFURL, options) else {
      return false
    }
    return CGImageSourceGetCount(source) > 1
  }

  /// Load and decode image from file URL
  private func loadImageFromFile(fileURL: URL, decodeForDisplay: Bool = true) async -> PlatformImage? {
    #if os(macOS)
      guard let image = NSImage(contentsOf: fileURL) else {
        return nil
      }
    #else
      guard let image = UIImage(contentsOfFile: fileURL.path) else {
        return nil
      }
    #endif

    guard decodeForDisplay else {
      return image
    }
    return await ImageDecodeHelper.decodeForDisplay(image)
  }

  private func preloadDecodedPageImage(pageIndex: Int) async -> (PlatformImage?, Bool, URL?) {
    guard let readerPage = readerPage(at: pageIndex) else {
      return (nil, false, nil)
    }
    let page = readerPage.page

    guard let sourceFileURL = await getPageImageFileURL(pageIndex: pageIndex) else {
      return (nil, false, nil)
    }

    let isAnimated = Self.detectAnimatedState(for: page, fileURL: sourceFileURL)
    let animatedFileURL = isAnimated ? sourceFileURL : nil
    let preferredFileURL = await preferredDisplayImageFileURL(
      page: page,
      pageID: readerPage.id,
      sourceFileURL: sourceFileURL,
      isAnimated: isAnimated
    )

    if let image = await loadImageFromFile(fileURL: preferredFileURL, decodeForDisplay: !isAnimated) {
      return (image, isAnimated, animatedFileURL)
    }

    if preferredFileURL != sourceFileURL {
      logger.debug(
        "⏭️ [Upscale] Fallback to original file for page \(page.number + 1) because @2x decode failed")
      let fallbackImage = await loadImageFromFile(fileURL: sourceFileURL, decodeForDisplay: !isAnimated)
      return (fallbackImage, isAnimated, animatedFileURL)
    }

    return (nil, isAnimated, animatedFileURL)
  }

  private func preferredDisplayImageFileURL(
    page: BookPage,
    pageID: ReaderPageID,
    sourceFileURL: URL,
    isAnimated: Bool
  ) async -> URL {
    guard !isAnimated else { return sourceFileURL }

    let mode = AppConfig.imageUpscalingMode
    guard mode != .disabled else { return sourceFileURL }

    guard let sourcePixelSize = Self.sourcePixelSize(page: page, fileURL: sourceFileURL) else {
      logger.debug("⏭️ [Upscale] Skip page \(page.number + 1): unable to resolve source size")
      return sourceFileURL
    }

    let autoTriggerScale = CGFloat(AppConfig.imageUpscaleAutoTriggerScale)
    let alwaysMaxScreenScale = CGFloat(AppConfig.imageUpscaleAlwaysMaxScreenScale)
    let screenPixelSize: CGSize
    #if os(iOS) || os(tvOS)
      screenPixelSize = ReaderUpscaleDecision.screenPixelSize(for: UIScreen.main)
    #elseif os(macOS)
      guard let mainScreen = NSScreen.main else {
        logger.debug("⏭️ [Upscale] Skip page \(page.number + 1): unable to resolve current screen")
        return sourceFileURL
      }
      screenPixelSize = ReaderUpscaleDecision.screenPixelSize(for: mainScreen)
    #endif
    let decision = ReaderUpscaleDecision.evaluate(
      mode: mode,
      sourcePixelSize: sourcePixelSize,
      screenPixelSize: screenPixelSize,
      autoTriggerScale: autoTriggerScale,
      alwaysMaxScreenScale: alwaysMaxScreenScale
    )
    guard decision.shouldUpscale else {
      let skipReasonText = Self.upscaleSkipReasonText(decision.reason)
      logger.debug(
        String(
          format:
            "⏭️ [Upscale] Skip page %d: reason=%@ mode=%@ requiredScale=%.2f source=%dx%d screen=%dx%d auto=%.2f always=%.2f",
          page.number + 1,
          skipReasonText,
          mode.rawValue,
          decision.requiredScale,
          Int(sourcePixelSize.width),
          Int(sourcePixelSize.height),
          Int(screenPixelSize.width),
          Int(screenPixelSize.height),
          autoTriggerScale,
          alwaysMaxScreenScale
        )
      )
      return sourceFileURL
    }

    let upscaledFileURLs = Self.upscaledImageFileURLs(from: sourceFileURL)
    if let cachedUpscaledURL = upscaledFileURLs.first(where: { FileManager.default.fileExists(atPath: $0.path) }) {
      logger.debug(
        "✅ [Upscale] Use cached @2x page \(page.number + 1): \(cachedUpscaledURL.lastPathComponent)")
      return cachedUpscaledURL
    }

    if let existingTask = upscalingTasks[pageID] {
      logger.debug("⏳ [Upscale] Await running upscale task for page \(page.number + 1)")
      if let cachedURL = await existingTask.value {
        logger.debug("✅ [Upscale] Reuse task result for page \(page.number + 1): \(cachedURL.lastPathComponent)")
        return cachedURL
      }
      logger.debug("⏭️ [Upscale] Running task failed for page \(page.number + 1), use source")
      return sourceFileURL
    }

    let pageNumber = page.number
    logger.debug(
      String(
        format: "🚀 [Upscale] Queue page %d: mode=%@ requiredScale=%.2f source=%dx%d",
        pageNumber + 1,
        mode.rawValue,
        decision.requiredScale,
        Int(sourcePixelSize.width),
        Int(sourcePixelSize.height)
      )
    )
    let upscaleTask = Task<URL?, Never>.detached(priority: .userInitiated) {
      [sourceFileURL, upscaledFileURLs, pageNumber] in
      let logger = AppLogger(.reader)

      if let cachedUpscaledURL = upscaledFileURLs.first(where: { FileManager.default.fileExists(atPath: $0.path) }) {
        logger.debug(
          "✅ [Upscale] Use cached @2x page \(pageNumber + 1): \(cachedUpscaledURL.lastPathComponent)")
        return cachedUpscaledURL
      }

      guard let sourceCGImage = Self.readCGImage(from: sourceFileURL) else {
        logger.debug("⏭️ [Upscale] Skip page \(pageNumber + 1): failed to decode source CGImage")
        return nil
      }

      let startedAt = Date()
      guard let output = await ReaderUpscaleModelManager.shared.process(sourceCGImage) else {
        logger.debug("⏭️ [Upscale] Skip page \(pageNumber + 1): model processing returned nil")
        return nil
      }

      guard
        let persistedURL = Self.persistUpscaledCGImage(
          output,
          sourceFileURL: sourceFileURL,
          targetFileURLs: upscaledFileURLs,
          logger: logger
        )
      else {
        logger.error(
          "❌ [Upscale] Failed to save @2x page \(pageNumber + 1): source=\(sourceFileURL.lastPathComponent)"
        )
        return nil
      }

      let duration = Date().timeIntervalSince(startedAt)
      logger.debug(
        String(
          format: "💾 [Upscale] Saved page %d @2x in %.2fs -> %@",
          pageNumber + 1,
          duration,
          persistedURL.lastPathComponent
        )
      )
      return persistedURL
    }

    upscalingTasks[pageID] = upscaleTask
    let result = await upscaleTask.value
    upscalingTasks.removeValue(forKey: pageID)
    if let result {
      logger.debug("✅ [Upscale] Ready page \(pageNumber + 1): \(result.lastPathComponent)")
    } else {
      logger.debug("⏭️ [Upscale] Use source for page \(pageNumber + 1): @2x generation unavailable")
    }
    return result ?? sourceFileURL
  }

  nonisolated private static func sourcePixelSize(page: BookPage, fileURL: URL) -> CGSize? {
    if let width = page.width, let height = page.height, width > 0, height > 0 {
      return CGSize(width: width, height: height)
    }

    let options = [kCGImageSourceShouldCache: false] as CFDictionary
    guard
      let source = CGImageSourceCreateWithURL(fileURL as CFURL, options),
      let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
      let pixelWidth = properties[kCGImagePropertyPixelWidth] as? CGFloat,
      let pixelHeight = properties[kCGImagePropertyPixelHeight] as? CGFloat,
      pixelWidth > 0,
      pixelHeight > 0
    else {
      return nil
    }

    return CGSize(width: pixelWidth, height: pixelHeight)
  }

  nonisolated private static func upscaledImageFileURLs(from sourceFileURL: URL) -> [URL] {
    let directory = sourceFileURL.deletingLastPathComponent()
    let baseName = sourceFileURL.deletingPathExtension().lastPathComponent
    let resolvedBaseName = baseName.hasSuffix("@2x") ? baseName : "\(baseName)@2x"

    let sourceExtension = sourceFileURL.pathExtension.lowercased()
    var candidates: [URL] = []

    if !sourceExtension.isEmpty {
      candidates.append(
        directory.appendingPathComponent(resolvedBaseName).appendingPathExtension(sourceExtension))
    } else {
      candidates.append(directory.appendingPathComponent(resolvedBaseName))
    }

    if sourceExtension != "jpg" && sourceExtension != "jpeg" {
      candidates.append(
        directory.appendingPathComponent(resolvedBaseName).appendingPathExtension("jpg"))
    }
    if sourceExtension != "png" {
      candidates.append(
        directory.appendingPathComponent(resolvedBaseName).appendingPathExtension("png"))
    }

    var seenPaths = Set<String>()
    return candidates.filter { seenPaths.insert($0.path).inserted }
  }

  nonisolated private static func readCGImage(from fileURL: URL) -> CGImage? {
    let options = [kCGImageSourceShouldCache: false] as CFDictionary
    guard let source = CGImageSourceCreateWithURL(fileURL as CFURL, options) else {
      return nil
    }
    return CGImageSourceCreateImageAtIndex(source, 0, options)
  }

  nonisolated private static let supportedDestinationTypeIdentifiers: Set<String> = {
    let identifiers = CGImageDestinationCopyTypeIdentifiers() as? [String] ?? []
    return Set(identifiers.map { $0.lowercased() })
  }()

  nonisolated private static func destinationUTType(for fileURL: URL) -> UTType? {
    let ext = fileURL.pathExtension.lowercased()
    guard !ext.isEmpty else { return nil }
    guard let type = UTType(filenameExtension: ext) else { return nil }
    guard supportedDestinationTypeIdentifiers.contains(type.identifier.lowercased()) else { return nil }
    return type
  }

  nonisolated private static func upscaleSkipReasonText(_ reason: ReaderUpscaleDecision.SkipReason?) -> String {
    switch reason {
    case .disabled:
      return "disabled"
    case .belowAutoTriggerScale:
      return "below-auto-trigger-threshold"
    case .exceedsAlwaysMaxScreenScale:
      return "exceeds-always-max-source-size"
    case .invalidSourceSize:
      return "invalid-source-size"
    case nil:
      return "unknown"
    }
  }

  nonisolated private static func persistUpscaledCGImage(
    _ image: CGImage,
    sourceFileURL: URL,
    targetFileURLs: [URL],
    logger: AppLogger
  ) -> URL? {
    let fileManager = FileManager.default
    guard let targetDirectory = targetFileURLs.first?.deletingLastPathComponent() else {
      logger.error("❌ [Upscale] No target path candidates for \(sourceFileURL.lastPathComponent)")
      return nil
    }
    do {
      try fileManager.createDirectory(at: targetDirectory, withIntermediateDirectories: true)
    } catch {
      logger.error("❌ [Upscale] Failed to create target directory: \(targetDirectory.path)")
      return nil
    }

    for targetFileURL in targetFileURLs {
      guard let destinationType = destinationUTType(for: targetFileURL) else {
        logger.debug(
          "⏭️ [Upscale] Unsupported destination type for \(targetFileURL.lastPathComponent), trying fallback")
        continue
      }

      guard
        let destination = CGImageDestinationCreateWithURL(
          targetFileURL as CFURL,
          destinationType.identifier as CFString,
          1,
          nil
        )
      else {
        logger.error(
          "❌ [Upscale] CGImageDestinationCreateWithURL failed: file=\(targetFileURL.lastPathComponent), type=\(destinationType.identifier)"
        )
        continue
      }

      CGImageDestinationAddImage(destination, image, nil)
      if CGImageDestinationFinalize(destination) {
        return targetFileURL
      }

      logger.error(
        "❌ [Upscale] CGImageDestinationFinalize failed: file=\(targetFileURL.lastPathComponent), type=\(destinationType.identifier)"
      )
    }

    return nil
  }

  func shouldShowAnimatedPlayButton(for pageID: ReaderPageID) -> Bool {
    #if os(tvOS)
      return false
    #else
      return animatedPageStates[pageID] == true
    #endif
  }

  func animatedPlaybackFileURL(for pageID: ReaderPageID) -> URL? {
    return animatedPageFileURLs[pageID]
  }

  func prepareAnimatedPagePlaybackURL(pageID: ReaderPageID) async -> URL? {
    guard let pageIndex = pageIndex(for: pageID) else { return nil }
    return await prepareAnimatedPagePlaybackURL(pageIndex: pageIndex)
  }

  /// Resolve local file URL for animated playback. Returns nil when this page is not animated.
  private func prepareAnimatedPagePlaybackURL(pageIndex: Int) async -> URL? {
    guard pageIndex >= 0 && pageIndex < readerPages.count else { return nil }
    guard let pageID = readerPageID(forPageIndex: pageIndex) else { return nil }
    let page = readerPages[pageIndex].page
    guard page.isAnimatedImageCandidate else {
      animatedPageStates[pageID] = false
      return nil
    }

    guard let fileURL = await getPageImageFileURL(pageIndex: pageIndex) else { return nil }
    let isAnimated = Self.detectAnimatedState(for: page, fileURL: fileURL)
    animatedPageStates[pageID] = isAnimated
    if isAnimated {
      animatedPageFileURLs[pageID] = fileURL
    } else {
      animatedPageFileURLs.removeValue(forKey: pageID)
    }
    return isAnimated ? fileURL : nil
  }

  /// Preload a single page image into memory for instant display.
  func preloadImageForPage(at pageIndex: Int) async -> PlatformImage? {
    guard let pageID = readerPageID(forPageIndex: pageIndex) else { return nil }
    if let cached = preloadedImagesByID[pageID] {
      return cached
    }
    let (image, isAnimated, animatedFileURL) = await preloadDecodedPageImage(pageIndex: pageIndex)
    animatedPageStates[pageID] = isAnimated
    if let animatedFileURL {
      animatedPageFileURLs[pageID] = animatedFileURL
    } else {
      animatedPageFileURLs.removeValue(forKey: pageID)
    }
    guard let image else {
      return nil
    }
    preloadedImagesByID[pageID] = image
    return image
  }

  func preloadImage(for pageID: ReaderPageID) async -> PlatformImage? {
    guard let pageIndex = pageIndex(for: pageID) else {
      return preloadedImagesByID[pageID]
    }
    return await preloadImageForPage(at: pageIndex)
  }

  /// Cancel any ongoing preloading tasks and clear preloaded images
  func clearPreloadedImages() {
    preloadTask?.cancel()
    preloadTask = nil
    for (_, task) in upscalingTasks {
      task.cancel()
    }
    upscalingTasks.removeAll()
    preloadedImagesByID.removeAll()
    animatedPageStates.removeAll()
    animatedPageFileURLs.removeAll()
    logger.debug("🗑️ Cleared all preloaded images and cancelled tasks")
  }

  /// Update reading progress on the server
  /// Uses API page number (1-based) instead of array index (0-based)
  /// Skip update if incognito mode is enabled
  func updateProgress() async {
    // Skip progress updates in incognito mode
    guard !incognitoMode else {
      logger.debug("⏭️ [Progress/Page] Skip capture: incognito mode enabled")
      return
    }
    guard let currentReaderPage else {
      logger.debug("⏭️ [Progress/Page] Skip capture: current page unavailable")
      return
    }
    let currentBookId = currentReaderPage.bookId

    let completed = isBookCompleted(for: currentReaderPage)
    logger.debug(
      "📝 [Progress/Page] Captured from reader state: book=\(currentBookId), page=\(currentReaderPage.pageNumber), completed=\(completed)"
    )

    await ReaderProgressDispatchService.shared.submitPageProgress(
      bookId: currentBookId,
      page: currentReaderPage.pageNumber,
      completed: completed
    )
  }

  func flushProgress() {
    guard !incognitoMode else {
      logger.debug("⏭️ [Progress/Page] Skip flush: incognito mode enabled")
      return
    }

    let snapshotBookId = currentReaderPage?.bookId
    let snapshotPage = currentReaderPage?.pageNumber
    let snapshotCompleted = currentReaderPage.map { isBookCompleted(for: $0) }

    logger.debug(
      "🚿 [Progress/Page] Flush requested from reader: book=\(snapshotBookId ?? "unknown"), hasCurrentPage=\(snapshotPage != nil)"
    )

    Task {
      guard let flushBookId = snapshotBookId else {
        logger.debug("⏭️ [Progress/Page] Skip flush: no active book ID")
        return
      }
      await ReaderProgressDispatchService.shared.flushPageProgress(
        bookId: flushBookId,
        snapshotPage: snapshotPage,
        snapshotCompleted: snapshotCompleted
      )
    }
  }

  private func isBookCompleted(for readerPage: ReaderPage) -> Bool {
    guard let range = segmentPageRangeByBookId[readerPage.bookId], !range.isEmpty else {
      return false
    }
    guard let currentPageIndex = pageIndex(for: readerPage.id) else { return false }
    return currentPageIndex >= range.upperBound - 1
  }

  private func resolvedDownloadURL(for page: BookPage, bookId: String) -> URL? {
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

    let currentPageID = resolvedCurrentPageID

    splitWidePageMode = mode
    regenerateViewState()

    requestNavigation(toPageID: currentPageID)
  }

  func updateActualDualPageMode(_ isUsing: Bool) {
    guard isActuallyUsingDualPageMode != isUsing else { return }
    isActuallyUsingDualPageMode = isUsing
    regenerateViewState()
  }

  func updateCombineSplitWidePagePairInDualMode(_ isEnabled: Bool) {
    guard combineSplitWidePagePairInDualMode != isEnabled else { return }
    combineSplitWidePagePairInDualMode = isEnabled
    regenerateViewState()
  }

  func toggleIsolatePage(_ pageID: ReaderPageID) {
    guard let isolatePosition = isolatePosition(for: pageID) else { return }
    toggleIsolatePage(at: isolatePosition)
  }

  private func toggleIsolatePage(at isolatePosition: (bookId: String, localIndex: Int)) {

    var localIsolatePages = isolatePagesByBookId[isolatePosition.bookId] ?? []
    if localIsolatePages.contains(isolatePosition.localIndex) {
      localIsolatePages.remove(isolatePosition.localIndex)
    } else {
      localIsolatePages.insert(isolatePosition.localIndex)
    }
    isolatePagesByBookId[isolatePosition.bookId] = localIsolatePages
    rebuildIsolatePageIndices()
    regenerateViewState()

    let sortedLocalPages = localIsolatePages.sorted()
    Task {
      await DatabaseOperator.shared.updateIsolatePages(
        bookId: isolatePosition.bookId,
        pages: sortedLocalPages
      )
      await DatabaseOperator.shared.commit()
    }
  }

  private func regenerateViewState() {
    let preservedCurrentItem = currentViewItemID
    let preservedCurrentPageID = currentPageID

    // Keep split-wide behavior available in dual mode as well.
    let effectiveSplitWidePages = splitWidePageMode.isEnabled

    // Cover page isolation only applies when NOT in single page mode
    // In single page mode, every page is already isolated
    let shouldIsolateCover = isolateCoverPageEnabled && (forceDualPagePairs || isActuallyUsingDualPageMode)

    viewItems = generateViewItems(
      segments: segments,
      readerPages: readerPages,
      noCover: !shouldIsolateCover,
      allowDualPairs: isActuallyUsingDualPageMode,
      forceDualPairs: forceDualPagePairs,
      combineSplitWidePagePairInDualMode: combineSplitWidePagePairInDualMode,
      splitWidePages: effectiveSplitWidePages,
      isolatePages: Set(isolatePages)
    )
    viewItemIndexByPage = generateViewItemIndexMap(items: viewItems)
    currentViewItemID = resolvedViewItem(
      preferredItem: preservedCurrentItem,
      preferredPageID: preservedCurrentPageID
    )
    currentPageID = currentViewItemID?.pageID ?? preservedCurrentPageID
  }

  func viewItem(at index: Int) -> ReaderViewItem? {
    guard index >= 0 && index < viewItems.count else { return nil }
    return viewItems[index]
  }

  func viewItem(for pageID: ReaderPageID) -> ReaderViewItem? {
    guard let index = viewItemIndexByPage[pageID] else { return nil }
    return viewItem(at: index)
  }

  func viewItemIndex(for item: ReaderViewItem) -> Int? {
    viewItems.firstIndex(of: item)
  }

  func requestNavigation(toPageID pageID: ReaderPageID?) {
    guard let pageID else {
      navigationTarget = nil
      return
    }
    navigationTarget = resolvedViewItem(preferredPageID: pageID)
  }

  func requestNavigation(toViewItem viewItem: ReaderViewItem?) {
    guard
      let viewItem = resolvedViewItem(
        preferredItem: viewItem,
        preferredPageID: viewItem?.pageID
      )
    else {
      navigationTarget = nil
      return
    }
    navigationTarget = viewItem
  }

  func clearNavigationTarget() {
    navigationTarget = nil
  }

  func adjacentViewItem(from item: ReaderViewItem? = nil, offset: Int) -> ReaderViewItem? {
    guard offset != 0 else {
      return item ?? currentViewItem()
    }
    let anchorItem = item ?? currentViewItem()
    guard let anchorItem, let anchorIndex = viewItemIndex(for: anchorItem) else {
      return nil
    }
    return viewItem(at: anchorIndex + offset)
  }

  func updateCurrentPosition(pageID: ReaderPageID?) {
    guard let pageID else {
      currentPageID = nil
      currentViewItemID = nil
      return
    }
    currentPageID = pageID
    currentViewItemID = resolvedViewItem(
      preferredPageID: pageID
    )
  }

  func updateCurrentPosition(viewItem: ReaderViewItem?) {
    guard let viewItem else {
      currentViewItemID = nil
      currentPageID = nil
      return
    }
    currentViewItemID = resolvedViewItem(
      preferredItem: viewItem,
      preferredPageID: viewItem.pageID
    )
    currentPageID = currentViewItemID?.pageID
  }

  func currentViewItem() -> ReaderViewItem? {
    resolvedViewItem(
      preferredItem: currentViewItemID,
      preferredPageID: currentPageID
    )
  }

  func isLeftSplitHalf(
    part: ReaderSplitPart,
    readingDirection: ReadingDirection,
    splitWidePageMode: SplitWidePageMode
  ) -> Bool {
    let isFirstHalf: Bool
    switch part {
    case .first:
      isFirstHalf = true
    case .second:
      isFirstHalf = false
    case .both:
      return true
    }
    let effectiveDirection = splitWidePageMode.effectiveReadingDirection(for: readingDirection)
    let shouldShowLeftFirst = effectiveDirection != .rtl
    return shouldShowLeftFirst ? isFirstHalf : !isFirstHalf
  }
}

private func generateViewItems(
  segments: [ReaderSegment],
  readerPages: [ReaderPage],
  noCover: Bool,
  allowDualPairs: Bool,
  forceDualPairs: Bool,
  combineSplitWidePagePairInDualMode: Bool,
  splitWidePages: Bool,
  isolatePages: Set<Int> = []
) -> [ReaderViewItem] {
  guard !segments.isEmpty, !readerPages.isEmpty else { return [] }

  var items: [ReaderViewItem] = []
  let shouldForceDualPairs = allowDualPairs && forceDualPairs

  var segmentStartIndex = 0
  for segment in segments {
    let segmentPageCount = segment.pages.count
    guard segmentPageCount > 0 else {
      continue
    }

    let segmentEndExclusive = segmentStartIndex + segmentPageCount
    var index = segmentStartIndex

    while index < segmentEndExclusive {
      if shouldForceDualPairs {
        let currentPage = readerPages[index].page
        let isWidePageEligibleForSplit =
          !currentPage.isPortrait
          && splitWidePages
          && !isolatePages.contains(index)
          && (noCover || index != segmentStartIndex)
          && index != segmentEndExclusive - 1

        if isWidePageEligibleForSplit {
          if combineSplitWidePagePairInDualMode {
            items.append(.split(id: readerPages[index].id, part: .both))
          } else {
            items.append(.split(id: readerPages[index].id, part: .first))
            items.append(.split(id: readerPages[index].id, part: .second))
          }
          index += 1
          continue
        }

        let shouldShowSingle =
          (!noCover && index == segmentStartIndex) || index == segmentEndExclusive - 1
          || isolatePages.contains(index) || isolatePages.contains(index + 1)
        if shouldShowSingle {
          items.append(.page(id: readerPages[index].id))
          index += 1
        } else {
          let nextIndex = index + 1
          items.append(.dual(first: readerPages[index].id, second: readerPages[nextIndex].id))
          index += 2
        }
        continue
      }

      let currentPage = readerPages[index].page

      var useSinglePage = false
      var shouldSplitPage = false

      // Check if wide page should be split (only if not already isolated or cover)
      let isWidePageEligibleForSplit =
        !currentPage.isPortrait
        && splitWidePages
        && !isolatePages.contains(index)
        && (noCover || index != segmentStartIndex)

      if isWidePageEligibleForSplit {
        shouldSplitPage = true
      }

      // Determine if page should be shown as single (without splitting)
      if !currentPage.isPortrait && !shouldSplitPage {
        useSinglePage = true
      }
      if !noCover && index == segmentStartIndex {
        useSinglePage = true
        shouldSplitPage = false
      }
      if isolatePages.contains(index) {
        useSinglePage = true
        shouldSplitPage = false
      }
      if index == segmentEndExclusive - 1 {
        useSinglePage = true
      }

      if shouldSplitPage {
        if combineSplitWidePagePairInDualMode && allowDualPairs {
          items.append(.split(id: readerPages[index].id, part: .both))
        } else {
          items.append(.split(id: readerPages[index].id, part: .first))
          items.append(.split(id: readerPages[index].id, part: .second))
        }
        index += 1
      } else if useSinglePage {
        items.append(.page(id: readerPages[index].id))
        index += 1
      } else {
        let nextPage = readerPages[index + 1].page
        if allowDualPairs && index + 1 < segmentEndExclusive
          && nextPage.isPortrait
          && !isolatePages.contains(index + 1)
        {
          items.append(.dual(first: readerPages[index].id, second: readerPages[index + 1].id))
          index += 2
        } else {
          items.append(.page(id: readerPages[index].id))
          index += 1
        }
      }
    }

    items.append(
      .end(id: readerPages[segmentEndExclusive - 1].id)
    )
    segmentStartIndex = segmentEndExclusive
  }

  return items
}

private func generateViewItemIndexMap(items: [ReaderViewItem]) -> [ReaderPageID: Int] {
  var indices: [ReaderPageID: Int] = [:]
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
      let pageID = item.pageID
      if indices[pageID] == nil {
        indices[pageID] = index
      }
    }
  }
  return indices
}
