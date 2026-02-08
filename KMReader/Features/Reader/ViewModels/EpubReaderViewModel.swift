//
//  EpubReaderViewModel.swift
//  KMReader
//
//  Created by Komga iOS Client
//

#if os(iOS)
  import Foundation
  import Observation
  import SwiftUI
  import UIKit

  struct WebPubLocation: Equatable {
    let href: String
    let title: String?
    let progression: Double?
    let totalProgression: Double?
    let pageIndex: Int
    let pageCount: Int
  }

  struct WebPubPageLocation: Equatable {
    let href: String
    let title: String?
    let type: String?
    let chapterIndex: Int
    let pageIndex: Int
    let pageCount: Int
    let url: URL
  }

  enum LoadingStage: String {
    case idle
    case fetchingMetadata
    case downloading
    case preparingReader
    case paginating
  }

  @MainActor
  @Observable
  class EpubReaderViewModel {
    var isLoading = false
    var errorMessage: String?
    var loadingStage: LoadingStage = .idle
    var downloadProgress: Double = 0.0
    var downloadBytesReceived: Int64 = 0
    var downloadBytesExpected: Int64?

    var tableOfContents: [WebPubLink] = []
    var currentChapterIndex: Int = 0
    var currentPageIndex: Int = 0
    var targetChapterIndex: Int?
    var targetPageIndex: Int?
    var currentLocation: WebPubLocation?
    var resourceRootURL: URL?
    var publicationLanguage: String?
    var publicationReadingProgression: WebPubReadingProgression?

    private var bookId: String = ""
    private var downloadInfo: DownloadInfo? = nil
    private var readingOrder: [WebPubLink] = []
    private var pageCountCache: [String: Int] = [:]
    private var chapterPageCounts: [Int: Int] = [:]
    private var chapterURLCache: [Int: URL] = [:]
    private var textLengthCache: [String: Int] = [:]
    private var chapterTextWeights: [Int: Int] = [:]
    private var totalTextWeight: Int = 0
    private var hasFullTextWeights = false
    private var tocTitleByHref: [String: String] = [:]
    private var maxProgressionByHref: [String: Float] = [:]
    private var positionsLoadTask: Task<[String: Float], Never>?
    private var textLengthTask: Task<Void, Never>?
    private var initialChapterIndex: Int?
    private var initialProgression: Double?
    private var downloadResumeTask: Task<Void, Never>?
    private var lastUpdateTime: Date = Date()
    private let updateThrottleInterval: TimeInterval = 2.0
    private let logger = AppLogger(.reader)
    private var viewportSize: CGSize = .zero
    private var preferences: EpubReaderPreferences = .init()
    private var theme: ReaderTheme = .lightSepia

    let incognito: Bool

    init(incognito: Bool) {
      self.incognito = incognito
    }

    func updateDownloadProgress(notification: Notification) {
      guard let progressKey = notification.userInfo?[DownloadProgressUserInfo.itemKey] as? String else { return }
      guard progressKey == self.bookId else { return }

      let expected = notification.userInfo?[DownloadProgressUserInfo.expectedKey] as? Int64
      let received = notification.userInfo?[DownloadProgressUserInfo.receivedKey] as? Int64 ?? 0

      self.downloadBytesReceived = received
      self.downloadBytesExpected = expected
      if let expected, expected > 0 {
        self.downloadProgress = Double(received) / Double(expected)
      } else {
        self.downloadProgress = 0.0
      }
    }

    func applyPreferences(_ prefs: EpubReaderPreferences, colorScheme: ColorScheme) {
      preferences = prefs
      theme = prefs.resolvedTheme(for: colorScheme)

      if !readingOrder.isEmpty, viewportSize.width > 0 {
        refreshChapterPageCounts(keepingCurrent: true)
      }
    }

    func updateViewport(size: CGSize) {
      let containerInsets = containerInsetsForLabels()
      let adjustedWidth = size.width - containerInsets.left - containerInsets.right
      let adjustedHeight = size.height - containerInsets.top - containerInsets.bottom
      let normalized = CGSize(width: floor(adjustedWidth), height: floor(adjustedHeight))
      guard normalized.width > 0, normalized.height > 0 else { return }
      guard normalized != viewportSize else { return }
      viewportSize = normalized

      if !readingOrder.isEmpty {
        refreshChapterPageCounts(keepingCurrent: true)
      }
    }

    func beginLoading() {
      isLoading = true
      errorMessage = nil
      loadingStage = .fetchingMetadata
      downloadProgress = 0.0
      downloadBytesReceived = 0
      downloadBytesExpected = nil
    }

    func load(book: Book) async {
      downloadInfo = book.downloadInfo
      await load(bookId: book.id)
    }

    private func load(bookId: String) async {
      downloadResumeTask?.cancel()
      downloadResumeTask = nil

      self.bookId = bookId
      isLoading = true
      errorMessage = nil
      loadingStage = .fetchingMetadata
      downloadProgress = 0.0
      downloadBytesReceived = 0
      downloadBytesExpected = nil
      tableOfContents = []
      currentChapterIndex = 0
      currentPageIndex = 0
      targetChapterIndex = nil
      targetPageIndex = nil
      currentLocation = nil
      resourceRootURL = nil
      publicationLanguage = nil
      publicationReadingProgression = nil
      chapterPageCounts = [:]
      chapterURLCache = [:]
      textLengthCache = [:]
      chapterTextWeights = [:]
      totalTextWeight = 0
      hasFullTextWeights = false
      tocTitleByHref = [:]
      maxProgressionByHref = [:]
      positionsLoadTask?.cancel()
      positionsLoadTask = nil
      textLengthTask?.cancel()
      textLengthTask = nil
      initialChapterIndex = nil
      initialProgression = nil

      do {
        logger.debug("WebPub load started for bookId=\(bookId)")

        let instanceId = AppConfig.current.instanceId
        guard let downloadInfo = downloadInfo else {
          throw AppErrorType.missingRequiredData(
            message: "Missing book metadata for offline download."
          )
        }
        try await ensureOfflineReady(downloadInfo: downloadInfo, instanceId: instanceId)

        guard let manifest = await DatabaseOperator.shared.fetchWebPubManifest(bookId: bookId) else {
          throw AppErrorType.missingRequiredData(
            message: "Missing WebPub manifest. Please re-download this book."
          )
        }
        logger.debug("WebPub manifest loaded from offline storage")
        publicationLanguage = manifest.metadata?.language
        publicationReadingProgression = manifest.metadata?.readingProgression

        guard
          let offlineRoot = await OfflineManager.shared.getOfflineWebPubRootURL(
            instanceId: instanceId,
            bookId: bookId
          )
        else {
          throw AppErrorType.missingRequiredData(
            message: "Offline resources are missing. Please re-download this book."
          )
        }

        downloadProgress = 1.0
        loadingStage = .preparingReader
        readingOrder = manifest.readingOrder
        tableOfContents = manifest.toc.isEmpty ? manifest.readingOrder : manifest.toc
        tocTitleByHref = buildTOCTitleMap(from: tableOfContents)

        resourceRootURL = offlineRoot
        copyCustomFontsToResourceDirectory()
        // Page count cache is memory-only, no file loading needed
        loadTextLengthCache()
        try await cacheChapterURLs()

        var savedProgression: R2Progression?
        if !incognito {
          savedProgression = try? await BookService.shared.getWebPubProgression(bookId: bookId)
        }

        if let savedProgression {
          logger.debug(
            "Fetched saved progression: href=\(savedProgression.locator.href), progression=\(savedProgression.locator.locations?.progression ?? 0)"
          )
          if let chapterIndex = chapterIndexForHref(savedProgression.locator.href) {
            logger.debug("Matched progression to chapterIndex=\(chapterIndex)")
            initialChapterIndex = chapterIndex
            initialProgression = Double(savedProgression.locator.locations?.progression ?? 0)
          } else {
            logger.debug("Failed to match progression href to any chapter in readingOrder")
          }
        }

        refreshChapterPageCounts(keepingCurrent: false)
        refreshChapterTextWeights()

        if let chapterIndex = initialChapterIndex,
          chapterIndex >= 0,
          chapterIndex < readingOrder.count
        {
          let pageCount = chapterPageCounts[chapterIndex] ?? 1
          let progression = initialProgression ?? 0
          let pageIndex = max(0, min(pageCount - 1, Int(floor(Double(pageCount) * progression))))
          currentChapterIndex = chapterIndex
          currentPageIndex = pageIndex
          targetChapterIndex = chapterIndex
          targetPageIndex = pageIndex
        } else if !readingOrder.isEmpty {
          currentChapterIndex = 0
          currentPageIndex = 0
          targetChapterIndex = 0
          targetPageIndex = 0
        }

        updateLocation(chapterIndex: currentChapterIndex, pageIndex: currentPageIndex)

        loadingStage = .idle
        isLoading = false
        logger.debug("WebPub load ready")

      } catch is CancellationError {
        logger.debug("WebPub load cancelled")
        let status = await OfflineManager.shared.getDownloadStatus(bookId: bookId)
        if case .pending = status {
          loadingStage = .downloading
          isLoading = true
          errorMessage = nil
          downloadResumeTask = Task { [weak self] in
            await self?.waitForDownloadAndReload(bookId: bookId)
          }
          return
        }

        loadingStage = .idle
        isLoading = false
      } catch {
        let message = error.localizedDescription
        errorMessage = message
        ErrorManager.shared.alert(error: error)
        loadingStage = .idle
        isLoading = false
        logger.error("WebPub load failed: \(message)")
      }
    }

    private func ensureOfflineReady(
      downloadInfo: DownloadInfo,
      instanceId: String
    ) async throws {
      let status = await OfflineManager.shared.getDownloadStatus(bookId: downloadInfo.bookId)
      if case .downloaded = status {
        return
      }

      if AppConfig.isOffline {
        throw AppErrorType.networkUnavailable
      }

      loadingStage = .downloading
      downloadProgress = 0.0
      downloadBytesReceived = 0
      downloadBytesExpected = nil

      switch status {
      case .notDownloaded:
        await OfflineManager.shared.toggleDownload(
          instanceId: instanceId,
          info: downloadInfo
        )
      case .failed:
        await OfflineManager.shared.retryDownload(instanceId: instanceId, bookId: bookId)
      case .pending:
        break
      case .downloaded:
        return
      }

      while true {
        if AppConfig.isOffline {
          throw AppErrorType.networkUnavailable
        }

        let currentStatus = await OfflineManager.shared.getDownloadStatus(bookId: bookId)
        switch currentStatus {
        case .downloaded:
          downloadProgress = 1.0
          return
        case .failed(let error):
          throw AppErrorType.operationFailed(message: error)
        case .notDownloaded:
          throw AppErrorType.operationFailed(
            message: "Download did not start. Please try again."
          )
        case .pending:
          if let progress = DownloadProgressTracker.shared.progress[bookId] {
            downloadProgress = progress
          }
        }

        try await Task.sleep(for: .milliseconds(200))
      }
    }

    private func waitForDownloadAndReload(bookId: String) async {
      while true {
        if AppConfig.isOffline {
          errorMessage = AppErrorType.networkUnavailable.localizedDescription
          loadingStage = .idle
          isLoading = false
          return
        }

        let status = await OfflineManager.shared.getDownloadStatus(bookId: bookId)
        switch status {
        case .downloaded:
          await load(bookId: bookId)
          return
        case .failed(let error):
          errorMessage = AppErrorType.operationFailed(message: error).localizedDescription
          loadingStage = .idle
          isLoading = false
          return
        case .notDownloaded:
          errorMessage =
            AppErrorType.operationFailed(
              message: "Download did not start. Please try again."
            ).localizedDescription
          loadingStage = .idle
          isLoading = false
          return
        case .pending:
          if let progress = DownloadProgressTracker.shared.progress[bookId] {
            downloadProgress = progress
          }
        }

        try? await Task.sleep(for: .milliseconds(300))
      }
    }

    func goToNextPage() {
      guard !readingOrder.isEmpty else { return }
      let pageCount = chapterPageCount(at: currentChapterIndex) ?? 1
      if currentPageIndex + 1 < pageCount {
        setTarget(chapterIndex: currentChapterIndex, pageIndex: currentPageIndex + 1)
      } else if currentChapterIndex + 1 < chapterCount {
        setTarget(chapterIndex: currentChapterIndex + 1, pageIndex: 0)
      }
    }

    func goToPreviousPage() {
      guard !readingOrder.isEmpty else { return }
      if currentPageIndex > 0 {
        setTarget(chapterIndex: currentChapterIndex, pageIndex: currentPageIndex - 1)
      } else if currentChapterIndex > 0 {
        let previousChapterIndex = currentChapterIndex - 1
        targetChapterIndex = previousChapterIndex
        targetPageIndex = -1
      }
    }

    func goToChapter(link: WebPubLink) {
      guard let chapterIndex = chapterIndexForHref(link.href) else { return }
      setTarget(chapterIndex: chapterIndex, pageIndex: 0)
    }

    func navigateToURL(_ url: URL) {
      // Extract possible hrefs from the URL
      let path = url.path
      let lastComponent = url.lastPathComponent

      // Split path into components and try matching progressively longer paths from the end
      let pathComponents = path.split(separator: "/").map(String.init)
      var possibleHrefs: [String] = [lastComponent]

      // Build paths from the end (e.g., "chapter1.xhtml", "OEBPS/chapter1.xhtml", "content/OEBPS/chapter1.xhtml")
      for i in (0..<pathComponents.count).reversed() {
        let subPath = pathComponents[i...].joined(separator: "/")
        if !possibleHrefs.contains(subPath) {
          possibleHrefs.append(subPath)
        }
      }

      // Also try the full path
      possibleHrefs.append(path.trimmingCharacters(in: CharacterSet(charactersIn: "/")))

      for href in possibleHrefs {
        if let chapterIndex = chapterIndexForHref(href) {
          setTarget(chapterIndex: chapterIndex, pageIndex: 0)
          return
        }
      }
    }

    func pageDidChange() {
      let chapterIndex = currentChapterIndex
      let pageIndex = currentPageIndex
      updateLocation(chapterIndex: chapterIndex, pageIndex: pageIndex)
      guard currentLocation != nil else {
        logger.debug("⏭️ Skip progression update because current location is unavailable")
        return
      }

      guard !incognito else {
        logger.debug("⏭️ Skip progression update because incognito mode is enabled")
        return
      }
      guard !bookId.isEmpty else {
        logger.warning("⚠️ Skip progression update because book ID is empty")
        return
      }

      let now = Date()
      let elapsed = now.timeIntervalSince(lastUpdateTime)
      guard elapsed >= updateThrottleInterval else {
        logger.debug(
          String(
            format: "⏱️ Skip progression update due to throttle (elapsed=%.2fs, required=%.2fs)",
            elapsed,
            updateThrottleInterval
          )
        )
        return
      }
      lastUpdateTime = now

      logger.debug(
        "📤 Trigger progression update from page change: chapterIndex=\(chapterIndex), pageIndex=\(pageIndex)"
      )

      Task {
        await updateProgression(chapterIndex: chapterIndex, pageIndex: pageIndex)
      }
    }

    var chapterCount: Int {
      readingOrder.count
    }

    var hasContent: Bool {
      !readingOrder.isEmpty
    }

    func lastPagePosition() -> (chapterIndex: Int, pageIndex: Int)? {
      guard !readingOrder.isEmpty else { return nil }
      let lastChapterIndex = readingOrder.count - 1
      let pageCount = chapterPageCount(at: lastChapterIndex) ?? 1
      return (lastChapterIndex, max(0, pageCount - 1))
    }

    func syncEndProgression() {
      guard !incognito else {
        logger.debug("⏭️ Skip end progression sync because incognito mode is enabled")
        return
      }
      guard !bookId.isEmpty else {
        logger.warning("⚠️ Skip end progression sync because book ID is empty")
        return
      }
      guard !AppConfig.isOffline else {
        logger.debug("⏭️ Skip end progression sync because app is offline")
        return
      }
      guard let lastPosition = lastPagePosition() else {
        logger.debug("⏭️ Skip end progression sync because last page position is unavailable")
        return
      }

      logger.debug(
        "🏁 Trigger end progression sync: chapterIndex=\(lastPosition.chapterIndex), pageIndex=\(lastPosition.pageIndex)"
      )
      updateLocation(chapterIndex: lastPosition.chapterIndex, pageIndex: lastPosition.pageIndex)

      Task {
        let href = readingOrder[lastPosition.chapterIndex].href
        let overrideProgression = await maxProgressionOverride(for: href)
        guard let overrideProgression else {
          logger.debug(
            "⏭️ Skip end progression sync because max progression override is unavailable for href=\(href)"
          )
          return
        }
        logger.debug(
          "📤 Sending end progression override for href=\(href), progression=\(overrideProgression)"
        )
        await updateProgression(
          chapterIndex: lastPosition.chapterIndex,
          pageIndex: lastPosition.pageIndex,
          chapterProgressOverride: Double(overrideProgression),
          totalProgressOverride: nil
        )
      }
    }

    func pageLocation(chapterIndex: Int, pageIndex: Int) -> WebPubPageLocation? {
      guard chapterIndex >= 0, chapterIndex < readingOrder.count else { return nil }
      let pageCount = max(1, chapterPageCounts[chapterIndex] ?? 1)
      guard pageIndex >= 0, pageIndex < pageCount else { return nil }
      guard let cachedURL = chapterURLCache[chapterIndex] else { return nil }

      let link = readingOrder[chapterIndex]
      let normalizedHref = Self.normalizedHref(link.href)
      let title = link.title ?? tocTitleByHref[normalizedHref]

      return WebPubPageLocation(
        href: link.href,
        title: title,
        type: link.type,
        chapterIndex: chapterIndex,
        pageIndex: pageIndex,
        pageCount: pageCount,
        url: cachedURL
      )
    }

    func prepareChapter(_ chapterIndex: Int) async {
      _ = chapterIndex
    }

    func chapterURL(at index: Int) -> URL? {
      chapterURLCache[index]
    }

    func chapterPageCount(at index: Int) -> Int? {
      chapterPageCounts[index]
    }

    func initialProgression(for chapterIndex: Int) -> Double? {
      guard initialChapterIndex == chapterIndex else { return nil }
      return initialProgression
    }

    func updateChapterPageCount(_ pageCount: Int, for chapterIndex: Int) {
      guard chapterIndex >= 0, chapterIndex < readingOrder.count else { return }
      let normalizedCount = max(1, pageCount)
      if chapterPageCounts[chapterIndex] == normalizedCount { return }

      chapterPageCounts[chapterIndex] = normalizedCount

      if chapterIndex == initialChapterIndex, let progression = initialProgression {
        let pageIndex = max(0, min(normalizedCount - 1, Int(floor(Double(normalizedCount) * progression))))
        logger.debug(
          "Applying initial progression to chapterIndex=\(chapterIndex): pageIndex=\(pageIndex)/\(normalizedCount)")
        let wasSamePosition = currentChapterIndex == chapterIndex && currentPageIndex == pageIndex
        currentChapterIndex = chapterIndex
        currentPageIndex = pageIndex
        if wasSamePosition {
          if targetChapterIndex == chapterIndex && targetPageIndex == pageIndex {
            // Avoid keeping a no-op target that can cause a late snap-back.
            targetChapterIndex = nil
            targetPageIndex = nil
          }
        } else {
          targetChapterIndex = chapterIndex
          targetPageIndex = pageIndex
        }
        initialChapterIndex = nil
        initialProgression = nil
      }

      normalizeCurrentPosition(adjustPageCount: false)
      normalizeTargetPosition(adjustPageCount: false)
      updateLocation(chapterIndex: currentChapterIndex, pageIndex: currentPageIndex)

      // Store in memory cache only (no file persistence)
      let effectiveViewport = viewportSize.width > 0 ? viewportSize : UIScreen.main.bounds.size
      let href = readingOrder[chapterIndex].href
      let cacheKey = pageCountCacheKey(for: href, viewport: effectiveViewport)
      pageCountCache[cacheKey] = normalizedCount
    }

    var labelTopOffset: CGFloat { UIDevice.current.userInterfaceIdiom == .pad ? 24 : 8 }
    var labelBottomOffset: CGFloat { UIDevice.current.userInterfaceIdiom == .pad ? 16 : 8 }
    var useSafeArea: Bool { UIDevice.current.userInterfaceIdiom != .pad }

    func containerInsetsForLabels() -> UIEdgeInsets {
      let topPadding = labelTopOffset + 24
      let bottomPadding = labelBottomOffset + 24
      return UIEdgeInsets(top: topPadding, left: 0, bottom: bottomPadding, right: 0)
    }

    // MARK: - Private Methods

    private func setTarget(chapterIndex: Int, pageIndex: Int) {
      guard !readingOrder.isEmpty else { return }
      let normalizedChapterIndex = max(0, min(chapterIndex, readingOrder.count - 1))
      let normalizedPageIndex = normalizedPageIndex(
        pageIndex,
        chapterIndex: normalizedChapterIndex,
        adjustPageCount: true
      )
      targetChapterIndex = normalizedChapterIndex
      targetPageIndex = normalizedPageIndex
    }

    private func normalizeCurrentPosition(adjustPageCount: Bool = true) {
      guard !readingOrder.isEmpty else {
        currentChapterIndex = 0
        currentPageIndex = 0
        return
      }
      let chapterIndex = max(0, min(currentChapterIndex, readingOrder.count - 1))
      let pageIndex = normalizedPageIndex(
        currentPageIndex,
        chapterIndex: chapterIndex,
        adjustPageCount: adjustPageCount
      )
      currentChapterIndex = chapterIndex
      currentPageIndex = pageIndex
    }

    private func normalizeTargetPosition(adjustPageCount: Bool = true) {
      guard let targetChapterIndex, let targetPageIndex else { return }
      guard !readingOrder.isEmpty else {
        self.targetChapterIndex = nil
        self.targetPageIndex = nil
        return
      }
      let chapterIndex = max(0, min(targetChapterIndex, readingOrder.count - 1))
      if targetPageIndex < 0 {
        self.targetChapterIndex = chapterIndex
        self.targetPageIndex = -1
        return
      }
      let pageIndex = normalizedPageIndex(
        targetPageIndex,
        chapterIndex: chapterIndex,
        adjustPageCount: adjustPageCount
      )
      self.targetChapterIndex = chapterIndex
      self.targetPageIndex = pageIndex
    }

    private func normalizedPageIndex(
      _ pageIndex: Int,
      chapterIndex: Int,
      adjustPageCount: Bool
    ) -> Int {
      let safeIndex = max(0, pageIndex)
      let storedCount = chapterPageCounts[chapterIndex] ?? 1
      let effectiveCount = adjustPageCount ? max(storedCount, safeIndex + 1) : storedCount
      if adjustPageCount, effectiveCount != storedCount {
        chapterPageCounts[chapterIndex] = effectiveCount
      }
      return min(safeIndex, effectiveCount - 1)
    }

    private func pageOffsetBeforeChapter(_ chapterIndex: Int) -> Int {
      guard chapterIndex > 0 else { return 0 }
      var offset = 0
      for idx in 0..<chapterIndex {
        offset += max(1, chapterPageCounts[idx] ?? 1)
      }
      return offset
    }

    private func totalPageCount() -> Int {
      guard !readingOrder.isEmpty else { return 0 }
      var total = 0
      for idx in 0..<readingOrder.count {
        total += max(1, chapterPageCounts[idx] ?? 1)
      }
      return total
    }

    private func buildTOCTitleMap(from links: [WebPubLink]) -> [String: String] {
      var map: [String: String] = [:]
      func collect(_ links: [WebPubLink]) {
        for link in links {
          if let title = link.title, !title.isEmpty {
            map[Self.normalizedHref(link.href)] = title
          }
          if let children = link.children {
            collect(children)
          }
        }
      }
      collect(links)
      return map
    }

    private func updateLocation(chapterIndex: Int, pageIndex: Int) {
      guard let location = pageLocation(chapterIndex: chapterIndex, pageIndex: pageIndex) else {
        currentLocation = nil
        return
      }
      let chapterProgress =
        location.pageCount > 0
        ? Double(location.pageIndex + 1) / Double(location.pageCount)
        : nil
      let total =
        hasFullTextWeights
        ? totalProgression(location: location, chapterProgress: chapterProgress)
        : nil
      currentLocation = WebPubLocation(
        href: location.href,
        title: location.title,
        progression: chapterProgress,
        totalProgression: total,
        pageIndex: location.pageIndex,
        pageCount: location.pageCount
      )
    }

    func totalProgression(
      location: WebPubPageLocation,
      chapterProgress: Double?
    ) -> Double? {
      if hasFullTextWeights,
        let chapterWeight = chapterTextWeights[location.chapterIndex],
        totalTextWeight > 0,
        let chapterProgress
      {
        var beforeWeight = 0
        if location.chapterIndex > 0 {
          for idx in 0..<location.chapterIndex {
            beforeWeight += chapterTextWeights[idx] ?? 0
          }
        }
        let progressed = Double(beforeWeight) + (chapterProgress * Double(chapterWeight))
        return progressed / Double(totalTextWeight)
      }

      let totalPages = totalPageCount()
      guard totalPages > 0 else { return nil }
      let pageOffset = pageOffsetBeforeChapter(location.chapterIndex)
      let overallIndex = pageOffset + location.pageIndex
      return Double(overallIndex + 1) / Double(totalPages)
    }

    private func updateProgression(
      chapterIndex: Int,
      pageIndex: Int,
      chapterProgressOverride: Double? = nil,
      totalProgressOverride: Double? = nil
    ) async {
      guard let location = pageLocation(chapterIndex: chapterIndex, pageIndex: pageIndex) else { return }
      let chapterProgress =
        chapterProgressOverride
        ?? (location.pageCount > 0
          ? Double(location.pageIndex) / Double(location.pageCount)
          : nil)
      let totalProgressionValue =
        totalProgressOverride
        ?? totalProgression(
          location: location,
          chapterProgress: chapterProgress
        )
        ?? 0

      let totalProgression = Float(totalProgressionValue)
      let chapterProgression: Float? = chapterProgress.map(Float.init)

      let r2Location = R2Locator.Location(
        fragments: nil,
        progression: chapterProgression,
        position: nil,
        totalProgression: totalProgression
      )

      let locator = R2Locator(
        href: stripResourcePrefix(location.href),
        type: location.type ?? "text/html",
        title: location.title,
        locations: r2Location,
        text: nil,
        koboSpan: nil
      )

      let progression = R2Progression(
        modified: Date(),
        device: R2Device(
          id: AppConfig.deviceIdentifier,
          name: AppConfig.userAgent
        ),
        locator: locator
      )

      let activeBookId = bookId
      let logger = self.logger

      let progressionData: Data?
      if AppConfig.isOffline {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        progressionData = try? encoder.encode(progression)
      } else {
        progressionData = nil
      }

      logger.debug(
        "📝 Prepared EPUB progression payload: href=\(locator.href), progression=\(locator.locations?.progression ?? 0), totalProgression=\(locator.locations?.totalProgression ?? 0), globalPage=\(pageOffsetBeforeChapter(chapterIndex) + pageIndex + 1), offline=\(AppConfig.isOffline)"
      )
      let pageOffset = pageOffsetBeforeChapter(chapterIndex)
      let globalPageNumber = pageOffset + pageIndex + 1

      logger.debug(
        "📮 Submit EPUB progression to dispatch service: book=\(activeBookId), href=\(locator.href), globalPage=\(globalPageNumber)"
      )

      await ReaderProgressDispatchService.shared.submitEpubProgression(
        bookId: activeBookId,
        globalPageNumber: globalPageNumber,
        progression: progression,
        progressionData: progressionData
      )
    }

    private func refreshChapterPageCounts(keepingCurrent: Bool) {
      guard !readingOrder.isEmpty else { return }

      var effectiveViewport = viewportSize
      if effectiveViewport.width <= 0 {
        effectiveViewport = UIScreen.main.bounds.size
      }

      for (index, link) in readingOrder.enumerated() {
        let cacheKey = pageCountCacheKey(for: link.href, viewport: effectiveViewport)
        let cachedCount = pageCountCache[cacheKey]
        chapterPageCounts[index] = max(1, cachedCount ?? 1)
      }
      if keepingCurrent {
        normalizeCurrentPosition()
        normalizeTargetPosition()
      }
      updateLocation(chapterIndex: currentChapterIndex, pageIndex: currentPageIndex)
    }

    private func refreshChapterTextWeights() {
      chapterTextWeights = [:]
      for (index, link) in readingOrder.enumerated() {
        let key = Self.normalizedHref(link.href)
        if let cached = textLengthCache[key] {
          chapterTextWeights[index] = max(1, cached)
        }
      }
      recomputeTextWeightState()
      computeMissingTextWeights()
    }

    private func recomputeTextWeightState() {
      totalTextWeight = chapterTextWeights.values.reduce(0, +)
      hasFullTextWeights = chapterTextWeights.count == readingOrder.count && totalTextWeight > 0
    }

    private func computeMissingTextWeights() {
      guard !readingOrder.isEmpty else { return }
      textLengthTask?.cancel()

      let readingOrder = self.readingOrder
      let chapterURLCache = self.chapterURLCache
      var localCache = textLengthCache

      textLengthTask = Task.detached(priority: .utility) { [weak self] in
        guard let self else { return }

        for (index, link) in readingOrder.enumerated() {
          if Task.isCancelled { return }
          let key = Self.normalizedHref(link.href)
          if localCache[key] != nil { continue }
          guard let url = chapterURLCache[index] else { continue }
          guard let data = try? Data(contentsOf: url) else { continue }
          let length = ReaderXHTMLParser.textLength(from: data, baseURL: url) ?? 0
          let normalizedLength = max(1, length)
          localCache[key] = normalizedLength

          await MainActor.run {
            self.textLengthCache[key] = normalizedLength
            self.chapterTextWeights[index] = normalizedLength
            self.recomputeTextWeightState()
            self.saveTextLengthCache()
            self.updateLocation(chapterIndex: self.currentChapterIndex, pageIndex: self.currentPageIndex)
          }
        }
      }
    }

    private func cacheChapterURLs() async throws {
      chapterURLCache = [:]
      for (index, link) in readingOrder.enumerated() {
        guard
          let cachedURL = await OfflineManager.shared.cachedOfflineWebPubResourceURL(
            instanceId: AppConfig.current.instanceId,
            bookId: bookId,
            href: link.href
          )
        else {
          throw AppErrorType.invalidFileURL(url: link.href)
        }
        chapterURLCache[index] = cachedURL
      }
    }

    private func loadTextLengthCache() {
      guard let rootURL = resourceRootURL else { return }
      let cacheURL = rootURL.appendingPathComponent("text-length.json", isDirectory: false)
      guard let data = try? Data(contentsOf: cacheURL) else { return }
      if let decoded = try? JSONDecoder().decode([String: Int].self, from: data) {
        textLengthCache = decoded
      }
    }

    private func saveTextLengthCache() {
      guard let rootURL = resourceRootURL else { return }
      let cacheURL = rootURL.appendingPathComponent("text-length.json", isDirectory: false)
      if let data = try? JSONEncoder().encode(textLengthCache) {
        try? data.write(to: cacheURL, options: [.atomic])
      }
    }

    private func pageCountCacheKey(for href: String, viewport: CGSize) -> String {
      let sizeKey = "\(Int(viewport.width))x\(Int(viewport.height))"
      let prefsKey = preferences.rawValue
      return "\(href)|\(sizeKey)|\(prefsKey)|\(theme.rawValue)"
    }

    private func chapterIndexForHref(_ href: String) -> Int? {
      let normalized = Self.normalizedHref(href)
      return readingOrder.firstIndex { Self.normalizedHref($0.href) == normalized }
    }

    /// Ensures a specific font is copied to the resource directory
    /// - Parameter fontName: The name of the font to copy
    func ensureFontCopied(fontName: String) {
      guard let rootURL = resourceRootURL else { return }
      guard let sourcePath = CustomFontStore.shared.getFontPath(for: fontName) else { return }

      let sourceURL = URL(fileURLWithPath: sourcePath)
      guard FileManager.default.fileExists(atPath: sourceURL.path) else { return }

      let fontsDirectory = rootURL.appendingPathComponent(".fonts", isDirectory: true)
      try? FileManager.default.createDirectory(at: fontsDirectory, withIntermediateDirectories: true)

      let fileName = sourceURL.lastPathComponent
      let destinationURL = fontsDirectory.appendingPathComponent(fileName)

      // Copy font file if it doesn't already exist
      if !FileManager.default.fileExists(atPath: destinationURL.path) {
        try? FileManager.default.copyItem(at: sourceURL, to: destinationURL)
      }
    }

    private func copyCustomFontsToResourceDirectory() {
      guard let rootURL = resourceRootURL else { return }

      // Create .fonts directory
      let fontsDirectory = rootURL.appendingPathComponent(".fonts", isDirectory: true)
      do {
        try FileManager.default.createDirectory(at: fontsDirectory, withIntermediateDirectories: true)
      } catch {
        print("⚠️ Failed to create fonts directory: \(error)")
        return
      }

      // Get all custom fonts with paths
      let customFonts = CustomFontStore.shared.fetchCustomFonts()

      for fontName in customFonts {
        guard let sourcePath = CustomFontStore.shared.getFontPath(for: fontName) else {
          continue
        }

        let sourceURL = URL(fileURLWithPath: sourcePath)

        // Check if source file exists
        guard FileManager.default.fileExists(atPath: sourceURL.path) else {
          print("⚠️ Font file not found for '\(fontName)': \(sourcePath)")
          continue
        }

        let fileName = sourceURL.lastPathComponent
        let destinationURL = fontsDirectory.appendingPathComponent(fileName)

        // Copy font file if it doesn't already exist
        if !FileManager.default.fileExists(atPath: destinationURL.path) {
          do {
            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
          } catch {
            print("⚠️ Failed to copy font '\(fontName)': \(error)")
          }
        }
      }
    }

    private func stripResourcePrefix(_ href: String) -> String {
      if let range = href.range(of: "/resource/", options: .backwards) {
        return String(href[range.upperBound...])
      }
      return href
    }

    private func maxProgressionOverride(for href: String) async -> Float? {
      let normalizedHref = Self.normalizedHref(href)
      if let cached = maxProgressionByHref[normalizedHref] {
        return cached
      }
      guard !AppConfig.isOffline, !bookId.isEmpty else { return nil }

      if let task = positionsLoadTask {
        let map = await task.value
        return map[normalizedHref]
      }

      let task = Task { [bookId] in
        do {
          let positions = try await BookService.shared.getWebPubPositions(bookId: bookId)
          var map: [String: Float] = [:]
          for locator in positions.positions {
            guard let progression = locator.locations?.progression else { continue }
            let key = Self.normalizedHref(locator.href)
            let existing = map[key] ?? -1
            if progression > existing {
              map[key] = progression
            }
          }
          return map
        } catch {
          return [:]
        }
      }

      positionsLoadTask = task
      let map = await task.value
      positionsLoadTask = nil
      if !map.isEmpty {
        maxProgressionByHref = map
      }
      return map[normalizedHref]
    }

    nonisolated private static func normalizedHref(_ href: String) -> String {
      var trimmed = href.trimmingCharacters(in: .whitespacesAndNewlines)

      // Handle full Komga resource URLs
      if let range = trimmed.range(of: "/resource/", options: .backwards) {
        trimmed = String(trimmed[range.upperBound...])
      }

      if let components = URLComponents(string: trimmed), !components.path.isEmpty {
        return components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
      }
      return trimmed.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }
  }

#endif
