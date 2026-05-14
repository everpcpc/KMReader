//
// ReaderViewModel.swift
//
//

import Foundation
import SwiftUI

@MainActor
@Observable
class ReaderViewModel {
  var readerPages: [ReaderPage] = []
  private(set) var segments: [ReaderSegment] = []
  var isolatePages: [Int] = []
  private var isolatePagesByBookId: [String: Set<Int>] = [:]
  private var pageRotationsByBookId: [String: [Int: Int]] = [:]
  private var currentPageID: ReaderPageID?
  private var currentViewItemID: ReaderViewItem?
  var navigationTarget: ReaderViewItem?
  var isLoading = true
  var loadingTitle = String(localized: "Loading book...")
  var loadingDetail: String?
  var loadingProgress: Double?
  var isDismissing = false
  var incognitoMode: Bool = false
  var isZoomed: Bool = false

  var viewItems: [ReaderViewItem] = []
  var viewItemIndexByPage: [ReaderPageID: Int] = [:]
  var tableOfContents: [ReaderTOCEntry] = []
  private var tableOfContentsByBookId: [String: [ReaderTOCEntry]] = [:]
  private var tableOfContentsBookId: String?
  private var isolateCoverPageEnabled: Bool
  private var forceDualPagePairs: Bool
  private var splitWidePageMode: SplitWidePageMode
  private var pageTransitionStyle: PageTransitionStyle
  private var isActuallyUsingDualPageMode: Bool = false
  typealias PagePresentationInvalidationHandler = @MainActor (ReaderPagePresentationInvalidation) -> Void
  @ObservationIgnored
  private var pagePresentationInvalidationHandlers: [UUID: PagePresentationInvalidationHandler] = [:]

  private let logger = AppLogger(.reader)
  private let pageLoadScheduler: ReaderPageLoadScheduler
  private var bookMediaProfile: MediaProfile = .unknown

  private var readerPageIndexByID: [ReaderPageID: Int] = [:]
  private var segmentPageRangeByBookId: [String: Range<Int>] = [:]
  private(set) var readerPagesVersion: Int = 0

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

  func isPageIsolated(_ pageID: ReaderPageID) -> Bool {
    guard let isolatePosition = isolatePosition(for: pageID) else { return false }
    return isolatePagesByBookId[isolatePosition.bookId]?.contains(isolatePosition.localIndex) == true
  }

  func pageRotationDegrees(for pageID: ReaderPageID) -> Int {
    guard let position = isolatePosition(for: pageID) else { return 0 }
    return pageRotationsByBookId[position.bookId]?[position.localIndex] ?? 0
  }

  var currentPageRotationDegrees: Int {
    guard let currentReaderPage else { return 0 }
    return pageRotationDegrees(for: currentReaderPage.id)
  }

  /// Whether the current page is a wide (non-portrait) image, which cannot be isolated.
  var isCurrentPageWide: Bool {
    guard let currentReaderPage else { return false }
    let rotation = pageRotationDegrees(for: currentReaderPage.id)
    let normalized = ((rotation % 360) + 360) % 360
    if normalized == 90 || normalized == 270 {
      return currentReaderPage.page.isPortrait
    }
    return !currentReaderPage.page.isPortrait
  }

  convenience init() {
    self.init(
      isolateCoverPage: AppConfig.isolateCoverPage,
      pageLayout: AppConfig.pageLayout,
      splitWidePageMode: AppConfig.splitWidePageMode,
      pageTransitionStyle: AppConfig.pageTransitionStyle,
      incognitoMode: false
    )
  }

  init(
    isolateCoverPage: Bool,
    pageLayout: PageLayout,
    splitWidePageMode: SplitWidePageMode = .none,
    pageTransitionStyle: PageTransitionStyle = AppConfig.pageTransitionStyle,
    incognitoMode: Bool = false
  ) {
    self.pageLoadScheduler = ReaderPageLoadScheduler()
    self.isolateCoverPageEnabled = isolateCoverPage
    self.forceDualPagePairs = pageLayout == .dual
    self.splitWidePageMode = splitWidePageMode
    self.pageTransitionStyle = pageTransitionStyle
    self.incognitoMode = incognitoMode
    pageLoadScheduler.setPresentationInvalidationHandler { [weak self] invalidation in
      self?.notifyPagePresentationInvalidation(invalidation)
    }
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
    pageLoadScheduler.updateReaderPages(flattenedReaderPages)
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
    pageLoadScheduler.preloadedImage(for: pageID)
  }

  func getPageImageFileURL(pageID: ReaderPageID) async -> URL? {
    await pageLoadScheduler.getPageImageFileURL(pageID: pageID)
  }

  func addPagePresentationInvalidationObserver(
    _ handler: @escaping PagePresentationInvalidationHandler
  ) -> UUID {
    let token = UUID()
    pagePresentationInvalidationHandlers[token] = handler
    return token
  }

  func removePagePresentationInvalidationObserver(_ token: UUID) {
    pagePresentationInvalidationHandlers.removeValue(forKey: token)
  }

  private func notifyPagePresentationInvalidation(
    _ invalidation: ReaderPagePresentationInvalidation
  ) {
    for handler in pagePresentationInvalidationHandlers.values {
      handler(invalidation)
    }
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

  func hasPendingImageLoad(for pageID: ReaderPageID) -> Bool {
    pageLoadScheduler.hasPendingImageLoad(for: pageID)
  }

  func prioritizeVisiblePageLoads(for pageIDs: [ReaderPageID]) {
    pageLoadScheduler.prioritizeVisiblePageLoads(for: pageIDs)
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

  /// End page is rendered between the finished segment book and its next sibling.
  /// The leading "previous" slot intentionally shows the finished/current segment book.
  func endPagePreviousBook(forSegmentBookId bookId: String) -> Book? {
    currentBook(forSegmentBookId: bookId)
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
    let database = await DatabaseOperator.databaseIfConfigured()

    if mediaProfile == .epub {
      if let localTOC = await database?.fetchTOC(id: book.id) {
        return localTOC
      }
      if !AppConfig.isOffline {
        do {
          let manifest = try await BookService.shared.getBookManifest(id: book.id)
          let toc = await ReaderManifestService(bookId: book.id).parseTOC(manifest: manifest)
          await database?.updateBookTOC(bookId: book.id, toc: toc)
          return toc
        } catch {
          logger.error("❌ Failed to load TOC from manifest for book \(book.id): \(error)")
          return []
        }
      }
      return []
    }

    if mediaProfile == .pdf {
      return await database?.fetchTOC(id: book.id) ?? []
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

  /// Update the adjacent-book metadata for an existing segment. Called when the
  /// reader's deferred adjacent-book fetch resolves so the segment's
  /// `previousBook`/`nextBook` reflect the freshly-fetched values, preventing
  /// redundant re-fetches from later code paths such as `resolveSegmentPreloadContext`
  /// that read these from the segment.
  ///
  /// No-op when no segment matches `bookId` — e.g., the user has navigated away
  /// before the deferred fetch resolved.
  func updateAdjacentBooksForSegment(
    bookId: String,
    previousBook: Book?,
    nextBook: Book?
  ) {
    updateSegmentContext(
      forCurrentBookId: bookId,
      previousBook: previousBook,
      nextBook: nextBook
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
    let database = await DatabaseOperator.databaseIfConfigured()

    if AppConfig.offlineFirstReading {
      do {
        try await ensureOfflineReady(book: book, updatesLoadingState: false)
      } catch {
        logger.error("❌ Failed to prepare offline segment for book \(book.id): \(error)")
        return nil
      }

      return await database?.fetchPages(id: book.id)
    }

    if let cachedPages = await database?.fetchPages(id: book.id) {
      return cachedPages
    }

    guard !AppConfig.isOffline else {
      return nil
    }

    do {
      let fetchedPages = try await BookService.shared.getBookPages(id: book.id)
      await database?.updateBookPages(bookId: book.id, pages: fetchedPages)
      return fetchedPages
    } catch {
      logger.error("❌ Failed to preload segment pages for book \(book.id): \(error)")
      return nil
    }
  }

  private func hydrateIsolatePages(for bookId: String) async {
    let database = await DatabaseOperator.databaseIfConfigured()
    let isolatePagesForBook = await database?.fetchIsolatePages(id: bookId) ?? []
    isolatePagesByBookId[bookId] = Set(isolatePagesForBook)
  }

  private func hydratePageRotations(for bookId: String) async {
    let database = await DatabaseOperator.databaseIfConfigured()
    let rotations = await database?.fetchPageRotations(id: bookId) ?? [:]
    pageRotationsByBookId[bookId] = rotations
  }

  private func persistPageRotations(_ rotations: [Int: Int], for bookId: String) {
    Task {
      if let database = await DatabaseOperator.databaseIfConfigured() {
        await database.updatePageRotations(bookId: bookId, rotations: rotations)
        await database.commit()
      }
    }
  }

  private func normalizedPageRotation(_ degrees: Int) -> Int {
    let normalized = degrees % 360
    return normalized >= 0 ? normalized : normalized + 360
  }

  private func restoreCurrentPosition(using currentPageID: ReaderPageID?) {
    guard currentPageID != nil else { return }
    updateCurrentPosition(pageID: currentPageID)
  }

  private func syncPageLoadSchedulerCurrentPage() {
    pageLoadScheduler.updateCurrentPageID(resolvedCurrentPageID)
  }

  private func resetStateForBookLoad() {
    pageLoadScheduler.resetForBookLoad()
    isolatePages.removeAll()
    isolatePagesByBookId.removeAll()
    pageRotationsByBookId.removeAll()
    tableOfContents.removeAll()
    tableOfContentsByBookId.removeAll()
    tableOfContentsBookId = nil
    segments.removeAll()
    readerPages.removeAll()
    viewItems.removeAll()
    viewItemIndexByPage.removeAll()
    readerPageIndexByID.removeAll()
    segmentPageRangeByBookId.removeAll()
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

    guard let fetchedPages = await fetchSegmentPages(for: nextBook) else {
      regenerateViewState()
      return
    }

    guard !fetchedPages.isEmpty else {
      regenerateViewState()
      return
    }

    await hydrateIsolatePages(for: nextBook.id)
    await hydratePageRotations(for: nextBook.id)
    let currentPageID = currentReaderPage?.id

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

    guard let fetchedPages = await fetchSegmentPages(for: previousBook) else {
      regenerateViewState()
      return
    }

    guard !fetchedPages.isEmpty else {
      regenerateViewState()
      return
    }

    await hydrateIsolatePages(for: previousBook.id)
    await hydratePageRotations(for: previousBook.id)
    let currentPageID = currentReaderPage?.id

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
    loadingTitle = String(localized: "Loading book...")
    loadingDetail = nil
    loadingProgress = nil

    resetStateForBookLoad()

    do {
      if AppConfig.offlineFirstReading {
        try await ensureOfflineReady(book: book, updatesLoadingState: true)
      }
      await prepareOfflinePDFForDivina(book: book)
      let database = await DatabaseOperator.databaseIfConfigured()

      let fetchedPages: [BookPage]
      if let localPages = await database?.fetchPages(id: book.id) {
        fetchedPages = localPages
      } else if !AppConfig.isOffline {
        fetchedPages = try await BookService.shared.getBookPages(id: book.id)
        await database?.updateBookPages(bookId: book.id, pages: fetchedPages)
      } else {
        throw APIError.offline
      }

      let localIsolatePages = await database?.fetchIsolatePages(id: book.id) ?? []
      isolatePagesByBookId[book.id] = Set(localIsolatePages)
      await hydratePageRotations(for: book.id)
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

  private func ensureOfflineReady(book: Book, updatesLoadingState: Bool) async throws {
    let downloadInfo = book.downloadInfo
    let status = await OfflineManager.shared.getDownloadStatus(bookId: book.id)
    if case .downloaded = status {
      if updatesLoadingState {
        loadingProgress = 1.0
      }
      return
    }

    if AppConfig.isOffline {
      throw AppErrorType.networkUnavailable
    }

    if updatesLoadingState {
      loadingTitle = String(localized: "Downloading book...")
      loadingDetail = nil
      loadingProgress = 0.0
    }

    switch status {
    case .notDownloaded, .failed, .pending:
      await OfflineManager.shared.downloadForReading(
        instanceId: AppConfig.current.instanceId,
        info: downloadInfo
      )
    case .downloaded:
      loadingProgress = 1.0
      return
    }

    while true {
      if AppConfig.isOffline {
        throw AppErrorType.networkUnavailable
      }

      let currentStatus = await OfflineManager.shared.getDownloadStatus(bookId: book.id)
      switch currentStatus {
      case .downloaded:
        if updatesLoadingState {
          loadingProgress = 1.0
        }
        return
      case .failed(let error):
        throw AppErrorType.operationFailed(message: error)
      case .notDownloaded:
        throw AppErrorType.operationFailed(
          message: String(localized: "Download did not start. Please try again.")
        )
      case .pending:
        if updatesLoadingState,
          let progress = DownloadProgressTracker.shared.progress[book.id]
        {
          loadingProgress = progress
        }
      }

      try await Task.sleep(for: .milliseconds(200))
    }
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

    let database = await DatabaseOperator.databaseIfConfigured()
    let localPages = await database?.fetchPages(id: book.id)
    let localTOC = await database?.fetchTOC(id: book.id)
    let hasLocalPages = !(localPages ?? []).isEmpty
    let hasLocalTOC = localTOC != nil
    let forceRebuildMetadata = !hasLocalPages || !hasLocalTOC
    if forceRebuildMetadata {
      logger.debug(
        "🛠️ Force PDF metadata rebuild for book \(book.id), hasPages=\(hasLocalPages), hasTOC=\(hasLocalTOC)"
      )
    }

    loadingTitle = String(localized: "Offline DIVINA Rendering")
    loadingDetail = nil
    loadingProgress = 0
    defer {
      loadingTitle = String(localized: "Loading book...")
      loadingDetail = nil
      loadingProgress = nil
    }

    guard
      let result = await PdfOfflinePreparationService.shared.prepare(
        instanceId: AppConfig.current.instanceId,
        bookId: book.id,
        documentURL: offlinePDFURL,
        forceRebuildMetadata: forceRebuildMetadata,
        onProgress: { [weak self] progress in
          guard let self else { return }
          self.loadingTitle = String(localized: "Offline DIVINA Rendering")
          self.loadingProgress = progress.fractionCompleted
          self.loadingDetail = "\(progress.completedPages) / \(progress.totalPages)"
        }
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

    if let database = await DatabaseOperator.databaseIfConfigured() {
      await database.updateBookPages(bookId: bookId, pages: result.pages)
      await database.updateBookTOC(bookId: bookId, toc: result.tableOfContents)
      await database.commit()
    }
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

  func preloadPages(bypassThrottle: Bool = false) async {
    syncPageLoadSchedulerCurrentPage()
    await pageLoadScheduler.preloadPages(bypassThrottle: bypassThrottle)
  }

  func cleanupDistantImagesAroundCurrentPage() {
    syncPageLoadSchedulerCurrentPage()
    pageLoadScheduler.cleanupDistantImagesAroundCurrentPage()
  }

  func isAnimatedPage(for pageID: ReaderPageID) -> Bool {
    pageLoadScheduler.isAnimatedPage(for: pageID)
  }

  func shouldPrepareAnimatedPlayback(for pageID: ReaderPageID) -> Bool {
    pageLoadScheduler.shouldPrepareAnimatedPlayback(for: pageID)
  }

  func animatedSourceFileURL(for pageID: ReaderPageID) -> URL? {
    pageLoadScheduler.animatedSourceFileURL(for: pageID)
  }

  func prepareAnimatedPagePlaybackURL(pageID: ReaderPageID) async {
    await pageLoadScheduler.prepareAnimatedPagePlaybackURL(pageID: pageID)
  }

  func preloadImage(for pageID: ReaderPageID) async -> PlatformImage? {
    await pageLoadScheduler.preloadImage(for: pageID)
  }

  func clearPreloadedImages() {
    pageLoadScheduler.clearPreloadedImages()
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

  func updateDualPageSettings(noCover: Bool) {
    let newIsolateCover = !noCover
    guard isolateCoverPageEnabled != newIsolateCover else { return }
    regenerateViewStatePreservingCurrentPage {
      isolateCoverPageEnabled = newIsolateCover
    }
  }

  func updatePageLayout(_ layout: PageLayout) {
    let shouldForceDualPage = layout == .dual
    guard forceDualPagePairs != shouldForceDualPage else { return }
    regenerateViewStatePreservingCurrentPage {
      forceDualPagePairs = shouldForceDualPage
    }
  }

  func updateSplitWidePageMode(_ mode: SplitWidePageMode) {
    guard splitWidePageMode != mode else { return }
    regenerateViewStatePreservingCurrentPage {
      splitWidePageMode = mode
    }
  }

  func updatePageTransitionStyle(_ style: PageTransitionStyle) {
    guard pageTransitionStyle != style else { return }
    regenerateViewStatePreservingCurrentPage {
      pageTransitionStyle = style
    }
  }

  func updateDualPagePresentationMode(_ isUsingDualPageMode: Bool) {
    guard isActuallyUsingDualPageMode != isUsingDualPageMode else { return }

    regenerateViewStatePreservingCurrentPage {
      isActuallyUsingDualPageMode = isUsingDualPageMode
    }
  }

  func setPageRotation(_ degrees: Int, for pageID: ReaderPageID) {
    guard let position = isolatePosition(for: pageID) else { return }
    let normalized = normalizedPageRotation(degrees)
    guard pageRotationDegrees(for: pageID) != normalized else { return }
    var rotations = pageRotationsByBookId[position.bookId] ?? [:]
    if normalized == 0 {
      rotations.removeValue(forKey: position.localIndex)
    } else {
      rotations[position.localIndex] = normalized
    }
    pageRotationsByBookId[position.bookId] = rotations
    persistPageRotations(rotations, for: position.bookId)
    regenerateViewStatePreservingCurrentPage {
      // rotation state already updated above
    }
    notifyPagePresentationInvalidation(.pages([pageID]))
  }

  func rotatePage(_ pageID: ReaderPageID, by degrees: Int) {
    let current = pageRotationDegrees(for: pageID)
    setPageRotation(current + degrees, for: pageID)
  }

  func toggleIsolatePage(_ pageID: ReaderPageID) {
    guard let isolatePosition = isolatePosition(for: pageID) else { return }
    // Wide pages (considering rotation) always fill both slots and cannot be isolated
    let rotation = pageRotationDegrees(for: pageID)
    let normalized = ((rotation % 360) + 360) % 360
    if let page = readerPage(for: pageID)?.page {
      let effectivelyPortrait: Bool
      if normalized == 90 || normalized == 270 {
        effectivelyPortrait = (page.width ?? 0) > (page.height ?? 0)
      } else {
        effectivelyPortrait = page.isPortrait
      }
      if !effectivelyPortrait { return }
    }
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
      if let database = await DatabaseOperator.databaseIfConfigured() {
        await database.updateIsolatePages(
          bookId: isolatePosition.bookId,
          pages: sortedLocalPages
        )
        await database.commit()
      }
    }
  }

  func preserveCurrentPageForPresentationRebuild() {
    requestNavigation(toPageID: resolvedCurrentPageID)
  }

  private func regenerateViewState() {
    let preservedCurrentItem = currentViewItemID
    let preservedCurrentPageID = resolvedCurrentPageID

    // Apply the split-wide preference consistently in single and dual presentations.
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
      splitWidePages: effectiveSplitWidePages,
      pageCurl: pageTransitionStyle == .pageCurl,
      isolatePages: Set(isolatePages),
      pageRotationsByBookId: pageRotationsByBookId,
      segmentPageRangeByBookId: segmentPageRangeByBookId
    )
    viewItemIndexByPage = generateViewItemIndexMap(items: viewItems)
    currentViewItemID = resolvedViewItem(
      preferredItem: preservedCurrentItem,
      preferredPageID: preservedCurrentPageID
    )
    currentPageID = resolvedCurrentPageID(
      for: currentViewItemID,
      preferredPageID: preservedCurrentPageID
    )
    syncPageLoadSchedulerCurrentPage()
  }

  private func regenerateViewStatePreservingCurrentPage(_ mutation: () -> Void) {
    let currentPageID = resolvedCurrentPageID
    mutation()
    regenerateViewState()
    requestNavigation(toPageID: currentPageID)
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
      syncPageLoadSchedulerCurrentPage()
      return
    }
    currentPageID = pageID
    currentViewItemID = resolvedViewItem(
      preferredPageID: pageID
    )
    syncPageLoadSchedulerCurrentPage()
  }

  private func resolvedCurrentPageID(
    for viewItem: ReaderViewItem?,
    preferredPageID: ReaderPageID?
  ) -> ReaderPageID? {
    guard let viewItem else { return preferredPageID }
    if let preferredPageID, viewItem.pageIDs.contains(preferredPageID) {
      return preferredPageID
    }
    return viewItem.pageID
  }

  func updateCurrentPosition(viewItem: ReaderViewItem?) {
    guard let viewItem else {
      currentViewItemID = nil
      currentPageID = nil
      syncPageLoadSchedulerCurrentPage()
      return
    }
    let preferredPageID = currentPageID
    currentViewItemID = resolvedViewItem(
      preferredItem: viewItem,
      preferredPageID: preferredPageID ?? viewItem.pageID
    )
    currentPageID = resolvedCurrentPageID(
      for: currentViewItemID,
      preferredPageID: preferredPageID
    )
    syncPageLoadSchedulerCurrentPage()
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
  splitWidePages: Bool,
  pageCurl: Bool,
  isolatePages: Set<Int> = [],
  pageRotationsByBookId: [String: [Int: Int]] = [:],
  segmentPageRangeByBookId: [String: Range<Int>] = [:]
) -> [ReaderViewItem] {
  guard !segments.isEmpty, !readerPages.isEmpty else { return [] }

  // Helper: determine effective isPortrait considering rotation
  func effectiveIsPortrait(at index: Int) -> Bool {
    let page = readerPages[index].page
    let bookId = readerPages[index].bookId
    if let range = segmentPageRangeByBookId[bookId] {
      let localIndex = index - range.lowerBound
      let rotation = pageRotationsByBookId[bookId]?[localIndex] ?? 0
      let normalized = ((rotation % 360) + 360) % 360
      if normalized == 90 || normalized == 270 {
        // Swapped: portrait becomes landscape and vice versa
        guard let width = page.width, let height = page.height else { return false }
        return width > height
      }
    }
    return page.isPortrait
  }

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
        let currentIsPortrait = effectiveIsPortrait(at: index)
        let isCoverPage = !noCover && index == segmentStartIndex
        let isWideCoverPage = isCoverPage && !currentIsPortrait
        let isWidePageEligibleForSplit =
          (splitWidePages || pageCurl)
          && !currentIsPortrait
          && (noCover || isWideCoverPage || index != segmentStartIndex)

        if isWidePageEligibleForSplit {
          items.append(.split(id: readerPages[index].id, part: .both))
          index += 1
          continue
        }

        if !currentIsPortrait && !pageCurl {
          items.append(.page(id: readerPages[index].id))
          index += 1
          continue
        }

        let nextIsPortrait = index + 1 < segmentEndExclusive ? effectiveIsPortrait(at: index + 1) : true
        let shouldShowSingle =
          (isCoverPage && currentIsPortrait) || index == segmentEndExclusive - 1
          || isolatePages.contains(index) || isolatePages.contains(index + 1)
          || !nextIsPortrait  // next page is wide → keep it for its own item
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

      let currentIsPortrait = effectiveIsPortrait(at: index)

      var useSinglePage = false
      var shouldSplitPage = false

      let isCoverPage = !noCover && index == segmentStartIndex
      let isWideCoverPage = isCoverPage && !currentIsPortrait

      // Wide pages split only when enabled. In dual-page mode that produces a two-slot
      // spread; otherwise the page stays as a single item.
      let isWidePageEligibleForSplit =
        (splitWidePages || (pageCurl && allowDualPairs))
        && !currentIsPortrait
        && (noCover || isWideCoverPage || index != segmentStartIndex)

      if isWidePageEligibleForSplit {
        shouldSplitPage = true
      }

      // Determine if page should be shown as single (without splitting)
      if !currentIsPortrait && !shouldSplitPage {
        useSinglePage = true
      }
      if isCoverPage && !isWideCoverPage {
        useSinglePage = true
      }
      if isolatePages.contains(index) {
        useSinglePage = true
      }
      if index == segmentEndExclusive - 1 {
        useSinglePage = true
      }

      if shouldSplitPage {
        if allowDualPairs {
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
        let nextIsPortrait = effectiveIsPortrait(at: index + 1)
        if allowDualPairs && index + 1 < segmentEndExclusive
          && nextIsPortrait
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
