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

  @MainActor
  @Observable
  class EpubReaderViewModel {
    enum LoadingStage: String {
      case idle
      case fetchingMetadata
      case downloading
      case preparingReader
      case paginating
    }

    var isLoading = false
    var errorMessage: String?
    var loadingStage: LoadingStage = .idle
    var downloadProgress: Double = 0.0
    var downloadBytesReceived: Int64 = 0
    var downloadBytesExpected: Int64?

    var pageLocations: [WebPubPageLocation] = []
    var tableOfContents: [WebPubLink] = []
    var currentPageIndex: Int = 0
    var targetPageIndex: Int?
    var currentLocation: WebPubLocation?
    var resourceRootURL: URL?

    private var bookId: String = ""
    private var readingOrder: [WebPubLink] = []
    private var pageCountCache: [String: Int] = [:]
    private var chapterPageCounts: [Int: Int] = [:]
    private var chapterURLCache: [Int: URL] = [:]
    private var textLengthCache: [String: Int] = [:]
    private var chapterTextWeights: [Int: Int] = [:]
    private var totalTextWeight: Int = 0
    private var hasFullTextWeights = false
    private var textLengthTask: Task<Void, Never>?
    private var initialChapterIndex: Int?
    private var initialProgression: Double?
    private var downloadResumeTask: Task<Void, Never>?
    private var lastUpdateTime: Date = Date()
    private let updateThrottleInterval: TimeInterval = 2.0
    private let logger = AppLogger(.reader)
    private var viewportSize: CGSize = .zero
    private var preferences: EpubReaderPreferences = .init()
    private var theme: ReaderTheme = .light

    let incognito: Bool
    var book: Book? = nil

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
      let normalized = CGSize(width: floor(size.width), height: floor(size.height))
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

    func load(bookId: String) async {
      downloadResumeTask?.cancel()
      downloadResumeTask = nil

      self.bookId = bookId
      isLoading = true
      errorMessage = nil
      loadingStage = .fetchingMetadata
      downloadProgress = 0.0
      downloadBytesReceived = 0
      downloadBytesExpected = nil
      pageLocations = []
      tableOfContents = []
      currentPageIndex = 0
      targetPageIndex = nil
      currentLocation = nil
      resourceRootURL = nil
      chapterPageCounts = [:]
      chapterURLCache = [:]
      textLengthCache = [:]
      chapterTextWeights = [:]
      totalTextWeight = 0
      hasFullTextWeights = false
      textLengthTask?.cancel()
      textLengthTask = nil
      initialChapterIndex = nil
      initialProgression = nil

      do {
        logger.debug("WebPub load started for bookId=\(bookId)")

        let instanceId = AppConfig.current.instanceId
        try await ensureBook()
        guard let book = self.book else {
          throw AppErrorType.missingRequiredData(
            message: "Missing book metadata for offline download."
          )
        }
        try await ensureOfflineReady(book: book, instanceId: instanceId)

        guard let manifest = await DatabaseOperator.shared.fetchWebPubManifest(bookId: bookId) else {
          throw AppErrorType.missingRequiredData(
            message: "Missing WebPub manifest. Please re-download this book."
          )
        }
        logger.debug("WebPub manifest loaded from offline storage")

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

        resourceRootURL = offlineRoot
        loadPageCountCache()
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

        if let chapterIndex = initialChapterIndex {
          let pageCount = chapterPageCounts[chapterIndex] ?? 1
          let progression = initialProgression ?? 0
          let pageIndex = max(0, min(pageCount - 1, Int(floor(Double(pageCount) * progression))))
          if let globalIndex = globalIndexForChapter(chapterIndex, pageIndex: pageIndex) {
            currentPageIndex = globalIndex
            targetPageIndex = globalIndex
          }
        } else if let index = globalIndexForChapter(initialChapterIndex ?? 0, pageIndex: 0) {
          currentPageIndex = index
          targetPageIndex = index
        }

        updateLocation(for: currentPageIndex)

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

    func retry() async {
      await load(bookId: bookId)
    }

    private func ensureBook() async throws {
      if let book = await DatabaseOperator.shared.fetchBook(id: bookId) {
        self.book = book
      } else if let book = try? await BookService.shared.getBook(id: bookId) {
        self.book = book
      } else {
        throw AppErrorType.missingRequiredData(
          message: "Missing book metadata for offline download."
        )
      }
    }

    private func ensureOfflineReady(book: Book, instanceId: String) async throws {
      let status = await OfflineManager.shared.getDownloadStatus(bookId: book.id)
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
          info: book.downloadInfo
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
      let nextIndex = currentPageIndex + 1
      guard nextIndex < pageLocations.count else { return }
      targetPageIndex = nextIndex
    }

    func goToPreviousPage() {
      let previousIndex = currentPageIndex - 1
      guard previousIndex >= 0 else { return }
      targetPageIndex = previousIndex
    }

    func goToChapter(link: WebPubLink) {
      guard chapterIndexForHref(link.href) != nil else { return }
      if let index = indexForHref(link.href, pageIndex: 0) {
        targetPageIndex = index
      }
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
        if let index = indexForHref(href, pageIndex: 0) {
          targetPageIndex = index
          return
        }
      }
    }

    func pageDidChange(to index: Int) {
      guard index >= 0, index < pageLocations.count else { return }
      currentPageIndex = index
      updateLocation(for: index)

      guard !incognito, !bookId.isEmpty else {
        return
      }

      let now = Date()
      guard now.timeIntervalSince(lastUpdateTime) >= updateThrottleInterval else {
        return
      }
      lastUpdateTime = now

      Task {
        await updateProgression(for: index)
      }
    }

    var chapterCount: Int {
      readingOrder.count
    }

    func pageLocation(at index: Int) -> WebPubPageLocation? {
      guard index >= 0, index < pageLocations.count else { return nil }
      return pageLocations[index]
    }

    func pageLocationForChapter(_ chapterIndex: Int, pageIndex: Int) -> WebPubPageLocation? {
      guard chapterIndex >= 0, chapterIndex < readingOrder.count else { return nil }
      return pageLocations.first {
        $0.chapterIndex == chapterIndex && $0.pageIndex == pageIndex
      }
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

    func globalIndexForChapter(_ chapterIndex: Int, pageIndex: Int) -> Int? {
      guard chapterIndex >= 0, chapterIndex < readingOrder.count else { return nil }
      var offset = 0
      for idx in 0..<chapterIndex {
        offset += max(1, chapterPageCounts[idx] ?? 1)
      }
      return max(0, offset + pageIndex)
    }

    private func estimatedTotalPageCount() -> Int {
      guard !readingOrder.isEmpty else { return 0 }
      var total = 0
      for idx in 0..<readingOrder.count {
        total += max(1, chapterPageCounts[idx] ?? 1)
      }
      return total
    }

    private func estimatedGlobalPosition(for location: WebPubPageLocation) -> Int {
      var offset = 0
      for idx in 0..<location.chapterIndex {
        offset += max(1, chapterPageCounts[idx] ?? 1)
      }
      return max(0, offset + location.pageIndex)
    }

    func updateChapterPageCount(_ pageCount: Int, for chapterIndex: Int) {
      guard chapterIndex >= 0, chapterIndex < readingOrder.count else { return }
      let normalizedCount = max(1, pageCount)
      if chapterPageCounts[chapterIndex] == normalizedCount { return }

      let currentLocation =
        (currentPageIndex >= 0 && currentPageIndex < pageLocations.count)
        ? pageLocations[currentPageIndex]
        : nil

      chapterPageCounts[chapterIndex] = normalizedCount
      pageLocations = buildPageLocationsFromPaginatedChapters()

      if let currentLocation, currentLocation.chapterIndex == chapterIndex,
        let newIndex = globalIndexForChapter(
          chapterIndex,
          pageIndex: min(currentLocation.pageIndex, normalizedCount - 1)
        )
      {
        currentPageIndex = newIndex
        updateLocation(for: newIndex)
      }

      if chapterIndex == initialChapterIndex, let progression = initialProgression {
        let pageIndex = max(0, min(normalizedCount - 1, Int(floor(Double(normalizedCount) * progression))))
        logger.debug(
          "Applying initial progression to chapterIndex=\(chapterIndex): pageIndex=\(pageIndex)/\(normalizedCount)")
        if let globalIndex = globalIndexForChapter(chapterIndex, pageIndex: pageIndex) {
          logger.debug("Jump to globalIndex=\(globalIndex)")
          currentPageIndex = globalIndex
          targetPageIndex = globalIndex
          updateLocation(for: globalIndex)
        }
        initialChapterIndex = nil
        initialProgression = nil
      }

      let effectiveViewport = viewportSize.width > 0 ? viewportSize : UIScreen.main.bounds.size
      let href = readingOrder[chapterIndex].href
      let cacheKey = pageCountCacheKey(for: href, viewport: effectiveViewport)
      pageCountCache[cacheKey] = normalizedCount
      savePageCountCache()
    }

    func pageInsets(for prefs: EpubReaderPreferences) -> UIEdgeInsets {
      return UIEdgeInsets(top: 72, left: 16, bottom: 72, right: 16)
    }

    // MARK: - Private Methods

    private func updateLocation(for index: Int) {
      guard index >= 0, index < pageLocations.count else {
        currentLocation = nil
        return
      }
      let location = pageLocations[index]
      let chapterProgress =
        location.pageCount > 0
        ? Double(location.pageIndex + 1) / Double(location.pageCount)
        : nil
      let total =
        hasFullTextWeights
        ? totalProgression(for: index, location: location, chapterProgress: chapterProgress)
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

    private func totalProgression(
      for index: Int,
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

      let totalPages = pageLocations.count
      guard totalPages > 0 else { return nil }
      return Double(index + 1) / Double(totalPages)
    }

    private func updateProgression(for index: Int) async {
      guard index >= 0, index < pageLocations.count else { return }
      let location = pageLocations[index]
      let chapterProgress =
        location.pageCount > 0
        ? Double(location.pageIndex + 1) / Double(location.pageCount)
        : nil
      let totalProgression = Float(
        totalProgression(
          for: index,
          location: location,
          chapterProgress: chapterProgress
        ) ?? 0)

      let chapterProgression: Float? = chapterProgress.map(Float.init)

      let r2Location = R2Locator.Location(
        fragments: nil,
        progression: chapterProgression,
        position: index + 1,
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

      Task.detached(priority: .utility) {
        do {
          if AppConfig.isOffline {
            await DatabaseOperator.shared.queuePendingProgress(
              instanceId: AppConfig.current.instanceId,
              bookId: activeBookId,
              page: index + 1,
              completed: false,
              progressionData: progressionData
            )
            await DatabaseOperator.shared.commit()
          } else {
            try await BookService.shared.updateWebPubProgression(
              bookId: activeBookId,
              progression: progression
            )
          }
        } catch {
          logger.error("Failed to update progression: \(error.localizedDescription)")
        }
      }
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

      rebuildPageLocations(keepingCurrent: keepingCurrent)
    }

    private func rebuildPageLocations(keepingCurrent: Bool) {
      let currentHref = keepingCurrent ? currentLocation?.href : nil
      let currentPageInChapter = keepingCurrent ? currentLocation?.pageIndex ?? 0 : 0

      pageLocations = buildPageLocationsFromPaginatedChapters()

      if let currentHref,
        let newIndex = indexForHref(currentHref, pageIndex: currentPageInChapter)
      {
        currentPageIndex = newIndex
      }
      updateLocation(for: currentPageIndex)
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
            self.updateLocation(for: self.currentPageIndex)
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

    private func buildPageLocationsFromPaginatedChapters() -> [WebPubPageLocation] {
      var results: [WebPubPageLocation] = []

      var tocTitleByHref: [String: String] = [:]
      for tocLink in tableOfContents {
        guard let title = tocLink.title, !title.isEmpty else { continue }
        tocTitleByHref[Self.normalizedHref(tocLink.href)] = title
      }

      for (chapterIndex, link) in readingOrder.enumerated() {
        let pageCount = max(1, chapterPageCounts[chapterIndex] ?? 1)
        guard let cachedURL = chapterURLCache[chapterIndex] else { continue }

        let normalizedHref = Self.normalizedHref(link.href)
        let title = link.title ?? tocTitleByHref[normalizedHref]

        for pageIndex in 0..<pageCount {
          results.append(
            WebPubPageLocation(
              href: link.href,
              title: title,
              type: link.type,
              chapterIndex: chapterIndex,
              pageIndex: pageIndex,
              pageCount: pageCount,
              url: cachedURL
            )
          )
        }
      }

      return results
    }

    private func loadPageCountCache() {
      guard let rootURL = resourceRootURL else { return }
      let cacheURL = rootURL.appendingPathComponent("pagination.json", isDirectory: false)
      guard let data = try? Data(contentsOf: cacheURL) else { return }
      if let decoded = try? JSONDecoder().decode([String: Int].self, from: data) {
        pageCountCache = decoded
      }
    }

    private func savePageCountCache() {
      guard let rootURL = resourceRootURL else { return }
      let cacheURL = rootURL.appendingPathComponent("pagination.json", isDirectory: false)
      if let data = try? JSONEncoder().encode(pageCountCache) {
        try? data.write(to: cacheURL, options: [.atomic])
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

    private func indexForHref(_ href: String, pageIndex: Int) -> Int? {
      let normalized = Self.normalizedHref(href)
      return pageLocations.firstIndex {
        Self.normalizedHref($0.href) == normalized && $0.pageIndex == pageIndex
      }
    }

    private func stripResourcePrefix(_ href: String) -> String {
      if let range = href.range(of: "/resource/", options: .backwards) {
        return String(href[range.upperBound...])
      }
      return href
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
