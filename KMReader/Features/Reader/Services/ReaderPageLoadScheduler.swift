import Foundation
import ImageIO
import SwiftUI
import UniformTypeIdentifiers

#if os(macOS)
  import AppKit
#endif

@MainActor
final class ReaderPageLoadScheduler {
  typealias PresentationInvalidationHandler = @MainActor (ReaderPagePresentationInvalidation) -> Void

  private struct URLLoadTaskRecord {
    let token: UUID
    let task: Task<URL?, Never>
  }

  private struct ImageLoadTaskRecord {
    let token: UUID
    let task: Task<PlatformImage?, Never>
  }

  private let logger = AppLogger(.reader)
  private let pageImageCache = ImageCache()
  private let preloadBefore: Int
  private let preloadAfter: Int
  private let keepRangeBefore: Int
  private let keepRangeAfter: Int

  private var readerPages: [ReaderPage] = []
  private var readerPageIndexByID: [ReaderPageID: Int] = [:]
  private var currentPageID: ReaderPageID?
  private var presentationInvalidationHandler: PresentationInvalidationHandler?

  private var preloadedImagesByID: [ReaderPageID: PlatformImage] = [:]
  private var animatedPageStates: [ReaderPageID: Bool] = [:]
  private var animatedPageSourceFileURLs: [ReaderPageID: URL] = [:]

  private var downloadingTasks: [ReaderPageID: URLLoadTaskRecord] = [:]
  private var upscalingTasks: [ReaderPageID: URLLoadTaskRecord] = [:]
  private var preloadingImageTasks: [ReaderPageID: ImageLoadTaskRecord] = [:]
  private var lastPreloadRequestTime: Date?
  private var preloadTask: Task<Void, Never>?

  init(
    preloadBefore: Int = ReaderConstants.preloadBefore,
    preloadAfter: Int = ReaderConstants.preloadAfter,
    keepRangeBefore: Int = ReaderConstants.keepRangeBefore,
    keepRangeAfter: Int = ReaderConstants.keepRangeAfter
  ) {
    self.preloadBefore = preloadBefore
    self.preloadAfter = preloadAfter
    self.keepRangeBefore = keepRangeBefore
    self.keepRangeAfter = keepRangeAfter
  }

  func setPresentationInvalidationHandler(_ handler: PresentationInvalidationHandler?) {
    presentationInvalidationHandler = handler
  }

  func updateReaderPages(_ readerPages: [ReaderPage]) {
    self.readerPages = readerPages
    var indexMap: [ReaderPageID: Int] = [:]
    indexMap.reserveCapacity(readerPages.count)
    for (index, readerPage) in readerPages.enumerated() {
      indexMap[readerPage.id] = index
    }
    readerPageIndexByID = indexMap

    if let currentPageID, readerPageIndexByID[currentPageID] == nil {
      self.currentPageID = readerPages.first?.id
    }
  }

  func updateCurrentPageID(_ pageID: ReaderPageID?) {
    if let pageID, readerPageIndexByID[pageID] != nil {
      currentPageID = pageID
    } else {
      currentPageID = readerPages.first?.id
    }
  }

  func getPageImageFileURL(pageID: ReaderPageID) async -> URL? {
    guard let pageIndex = pageIndex(for: pageID) else { return nil }
    return await getPageImageFileURL(pageIndex: pageIndex)
  }

  func preloadedImage(for pageID: ReaderPageID) -> PlatformImage? {
    preloadedImagesByID[pageID]
  }

  func hasPendingImageLoad(for pageID: ReaderPageID) -> Bool {
    preloadingImageTasks[pageID] != nil
      || downloadingTasks[pageID] != nil
      || upscalingTasks[pageID] != nil
  }

  func prioritizeVisiblePageLoads(for pageIDs: [ReaderPageID]) {
    let keepPageIDs = prioritizedPageIDs(around: pageIDs)
    guard !keepPageIDs.isEmpty else { return }

    preloadTask?.cancel()
    preloadTask = nil
    lastPreloadRequestTime = nil

    cancelTrackedURLTasksOutsideWindow(&downloadingTasks, keeping: keepPageIDs)
    cancelTrackedURLTasksOutsideWindow(&upscalingTasks, keeping: keepPageIDs)
    cancelTrackedImageTasksOutsideWindow(&preloadingImageTasks, keeping: keepPageIDs)
  }

  func preloadPages(bypassThrottle: Bool = false) async {
    let now = Date()
    if !bypassThrottle,
      let last = lastPreloadRequestTime,
      now.timeIntervalSince(last) < 0.3
    {
      return
    }
    lastPreloadRequestTime = now

    let pagesToPreload = pageWindowEntries(
      around: currentPageID,
      before: preloadBefore,
      after: max(preloadAfter - 1, 0)
    )
    guard !pagesToPreload.isEmpty else { return }

    preloadTask?.cancel()
    preloadTask = Task { [weak self] in
      guard let self else { return }

      let results = await withTaskGroup(of: (Int, ReaderPageID, PlatformImage?, URL?).self) {
        group -> [(Int, ReaderPageID, PlatformImage?, URL?)] in
        for (index, pageID) in pagesToPreload {
          if Task.isCancelled { break }
          if self.preloadedImage(for: pageID) != nil {
            continue
          }
          group.addTask {
            if Task.isCancelled { return (index, pageID, nil, nil) }
            let (image, animatedSourceFileURL) = await self.preloadDecodedPageImage(pageIndex: index)
            return (index, pageID, image, animatedSourceFileURL)
          }
        }

        var collected: [(Int, ReaderPageID, PlatformImage?, URL?)] = []
        for await result in group {
          if !Task.isCancelled {
            collected.append(result)
          }
        }
        return collected
      }

      if Task.isCancelled { return }

      for (pageIndex, pageID, image, animatedSourceFileURL) in results {
        self.updateAnimatedPresentation(
          knownAnimatedState: animatedSourceFileURL != nil,
          sourceFileURL: animatedSourceFileURL,
          for: pageID
        )
        if let image {
          self.setPreloadedImage(image, forPageIndex: pageIndex)
        }
      }

      self.cleanupDistantImagesAroundCurrentPage()
    }
  }

  func cleanupDistantImagesAroundCurrentPage() {
    let keepPageIDs = Set(
      pageWindowEntries(
        around: currentPageID,
        before: keepRangeBefore,
        after: keepRangeAfter
      ).map(\.pageID)
    )
    guard !keepPageIDs.isEmpty else { return }

    let imageKeysToRemove = preloadedImagesByID.keys.filter { !keepPageIDs.contains($0) }
    for key in imageKeysToRemove {
      clearPreloadedImage(for: key)
    }

    let animatedKeysToRemove = Set(animatedPageStates.keys)
      .union(animatedPageSourceFileURLs.keys)
      .filter { !keepPageIDs.contains($0) }

    for key in animatedKeysToRemove {
      updateAnimatedPresentation(knownAnimatedState: nil, sourceFileURL: nil, for: key)
    }

    logger.debug("🖼️ Memory Cache: \(preloadedImagesByID.count) images")
  }

  func isAnimatedPage(for pageID: ReaderPageID) -> Bool {
    animatedPageStates[pageID] == true
  }

  func shouldPrepareAnimatedPlayback(for pageID: ReaderPageID) -> Bool {
    animatedPageStates[pageID] != false
  }

  func animatedSourceFileURL(for pageID: ReaderPageID) -> URL? {
    guard animatedPageStates[pageID] == true else { return nil }
    guard let fileURL = animatedPageSourceFileURLs[pageID] else { return nil }
    guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
    return fileURL
  }

  func prepareAnimatedPagePlaybackURL(pageID: ReaderPageID) async {
    guard let pageIndex = pageIndex(for: pageID) else { return }
    await prepareAnimatedPagePlaybackURL(pageIndex: pageIndex)
  }

  func preloadImageForPage(at pageIndex: Int) async -> PlatformImage? {
    guard let pageID = readerPageID(forPageIndex: pageIndex) else { return nil }
    if let cached = preloadedImagesByID[pageID] {
      return cached
    }

    if let existingTask = preloadingImageTasks[pageID] {
      return await existingTask.task.value
    }

    let taskToken = UUID()
    let preloadTask = Task<PlatformImage?, Never> { [weak self] in
      guard let self else { return nil }
      let (image, animatedSourceFileURL) = await self.preloadDecodedPageImage(pageIndex: pageIndex)
      guard !Task.isCancelled else { return nil }

      self.updateAnimatedPresentation(
        knownAnimatedState: animatedSourceFileURL != nil,
        sourceFileURL: animatedSourceFileURL,
        for: pageID
      )
      guard let image else { return nil }

      self.setPreloadedImage(image, for: pageID)
      return image
    }

    preloadingImageTasks[pageID] = ImageLoadTaskRecord(token: taskToken, task: preloadTask)
    let image = await preloadTask.value
    removeTrackedImageTaskIfCurrent(for: pageID, token: taskToken, from: &preloadingImageTasks)
    return image
  }

  func preloadImage(for pageID: ReaderPageID) async -> PlatformImage? {
    guard let pageIndex = pageIndex(for: pageID) else {
      return preloadedImagesByID[pageID]
    }
    return await preloadImageForPage(at: pageIndex)
  }

  func clearPreloadedImages() {
    preloadTask?.cancel()
    preloadTask = nil
    lastPreloadRequestTime = nil

    for (_, taskRecord) in downloadingTasks {
      taskRecord.task.cancel()
    }
    downloadingTasks.removeAll()

    for (_, taskRecord) in upscalingTasks {
      taskRecord.task.cancel()
    }
    upscalingTasks.removeAll()

    for (_, taskRecord) in preloadingImageTasks {
      taskRecord.task.cancel()
    }
    preloadingImageTasks.removeAll()

    preloadedImagesByID.removeAll()
    animatedPageStates.removeAll()
    animatedPageSourceFileURLs.removeAll()
    invalidatePresentation(.all)
    logger.debug("🗑️ Cleared all preloaded images and cancelled tasks")
  }

  func resetForBookLoad() {
    clearPreloadedImages()
    readerPages.removeAll()
    readerPageIndexByID.removeAll()
    currentPageID = nil
  }

  private func pageIndex(for pageID: ReaderPageID) -> Int? {
    readerPageIndexByID[pageID]
  }

  private func readerPage(at pageIndex: Int) -> ReaderPage? {
    guard pageIndex >= 0 && pageIndex < readerPages.count else { return nil }
    return readerPages[pageIndex]
  }

  private func readerPageID(forPageIndex pageIndex: Int) -> ReaderPageID? {
    guard pageIndex >= 0 && pageIndex < readerPages.count else { return nil }
    return readerPages[pageIndex].id
  }

  private func pageWindowEntries(around pageID: ReaderPageID?, before: Int, after: Int)
    -> [(index: Int, pageID: ReaderPageID)]
  {
    guard let pageID, let centerIndex = pageIndex(for: pageID), !readerPages.isEmpty else { return [] }
    let lowerIndex = max(centerIndex - max(before, 0), 0)
    let upperIndex = min(centerIndex + max(after, 0), max(readerPages.count - 1, 0))
    guard lowerIndex <= upperIndex else { return [] }

    return readerPages[lowerIndex...upperIndex].enumerated().map { offset, readerPage in
      (index: lowerIndex + offset, pageID: readerPage.id)
    }
  }

  private func prioritizedPageIDs(around pageIDs: [ReaderPageID]) -> Set<ReaderPageID> {
    var keepPageIDs = Set(pageIDs)
    for pageID in pageIDs {
      keepPageIDs.formUnion(
        pageWindowEntries(
          around: pageID,
          before: preloadBefore,
          after: preloadAfter
        ).map(\.pageID)
      )
    }
    return keepPageIDs
  }

  private func setPreloadedImage(_ image: PlatformImage, forPageIndex pageIndex: Int) {
    guard let pageID = readerPageID(forPageIndex: pageIndex) else { return }
    setPreloadedImage(image, for: pageID)
  }

  private func setPreloadedImage(_ image: PlatformImage, for pageID: ReaderPageID) {
    preloadedImagesByID[pageID] = image
    invalidatePresentation(.pages([pageID]))
  }

  private func clearPreloadedImage(for pageID: ReaderPageID) {
    guard preloadedImagesByID.removeValue(forKey: pageID) != nil else { return }
    invalidatePresentation(.pages([pageID]))
  }

  private func invalidatePresentation(_ invalidation: ReaderPagePresentationInvalidation) {
    presentationInvalidationHandler?(invalidation)
  }

  private func removeTrackedURLTaskIfCurrent(
    for pageID: ReaderPageID,
    token: UUID,
    from tasks: inout [ReaderPageID: URLLoadTaskRecord]
  ) {
    guard tasks[pageID]?.token == token else { return }
    tasks.removeValue(forKey: pageID)
  }

  private func removeTrackedImageTaskIfCurrent(
    for pageID: ReaderPageID,
    token: UUID,
    from tasks: inout [ReaderPageID: ImageLoadTaskRecord]
  ) {
    guard tasks[pageID]?.token == token else { return }
    tasks.removeValue(forKey: pageID)
  }

  private func cancelTrackedURLTasksOutsideWindow(
    _ tasks: inout [ReaderPageID: URLLoadTaskRecord],
    keeping keepPageIDs: Set<ReaderPageID>
  ) {
    let stalePageIDs = tasks.keys.filter { !keepPageIDs.contains($0) }
    for pageID in stalePageIDs {
      tasks[pageID]?.task.cancel()
      tasks.removeValue(forKey: pageID)
    }
  }

  private func cancelTrackedImageTasksOutsideWindow(
    _ tasks: inout [ReaderPageID: ImageLoadTaskRecord],
    keeping keepPageIDs: Set<ReaderPageID>
  ) {
    let stalePageIDs = tasks.keys.filter { !keepPageIDs.contains($0) }
    for pageID in stalePageIDs {
      tasks[pageID]?.task.cancel()
      tasks.removeValue(forKey: pageID)
    }
  }

  nonisolated private static func detectAnimatedState(for page: BookPage, fileURL: URL) -> Bool {
    guard page.isAnimatedImageCandidate else { return false }
    return AnimatedImageSupport.isAnimatedImageFile(at: fileURL)
  }

  private func getPageImageFileURL(pageIndex: Int) async -> URL? {
    guard let readerPage = readerPage(at: pageIndex) else {
      logger.warning("⚠️ Invalid page index \(pageIndex), cannot load page image")
      return nil
    }

    let pageID = readerPage.id
    let page = readerPage.page
    let currentBookId = readerPage.bookId

    if let existingTask = downloadingTasks[pageID] {
      logger.debug("⏳ Waiting for existing download task for page \(page.number) for book \(currentBookId)")
      if let result = await existingTask.task.value {
        return result
      }
      if let cachedFileURL = await getCachedImageFileURL(for: readerPage) {
        return cachedFileURL
      }
      return nil
    }

    let taskToken = UUID()
    let loadTask = Task<URL?, Never> {
      guard !Task.isCancelled else { return nil }

      let ext = page.detectedUTType?.preferredFilenameExtension ?? "jpg"
      if let offlineURL = await OfflineManager.shared.getOfflinePageImageURL(
        instanceId: AppConfig.current.instanceId,
        bookId: currentBookId,
        pageNumber: page.number,
        fileExtension: ext
      ) {
        self.logger.debug("✅ Using offline downloaded image for page \(page.number) for book \(currentBookId)")
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
          self.logger.error("❌ Unable to resolve download URL for page \(page.number) in book \(currentBookId)")
          return nil
        }

        let result = try await BookService.shared.downloadImageResource(at: remoteURL)
        guard !Task.isCancelled else { return nil }

        let data = result.data
        let dataSize = ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .binary)
        self.logger.info(
          "✅ Downloaded page \(page.number) successfully (\(dataSize)) for book \(currentBookId)"
        )

        await self.pageImageCache.storeImageData(
          data,
          bookId: currentBookId,
          page: page
        )

        if let fileURL = await self.getCachedImageFileURL(for: readerPage) {
          self.logger.debug("💾 Saved page \(page.number) to disk cache for book \(currentBookId)")
          return fileURL
        }

        self.logger.error(
          "❌ Failed to get file URL after saving page \(page.number) to cache for book \(currentBookId)"
        )
        return nil
      } catch {
        self.logger.error("❌ Failed to download page \(page.number) for book \(currentBookId): \(error)")
        return nil
      }
    }

    downloadingTasks[pageID] = URLLoadTaskRecord(token: taskToken, task: loadTask)
    let result = await loadTask.value
    removeTrackedURLTaskIfCurrent(for: pageID, token: taskToken, from: &downloadingTasks)
    return result
  }

  private func getCachedImageFileURL(for readerPage: ReaderPage) async -> URL? {
    if await pageImageCache.hasImage(bookId: readerPage.bookId, page: readerPage.page) {
      return pageImageCache.imageFileURL(bookId: readerPage.bookId, page: readerPage.page)
    }
    return nil
  }

  private func loadImageFromFile(fileURL: URL) async -> PlatformImage? {
    let image = await Task.detached(priority: .userInitiated) {
      #if os(macOS)
        return NSImage(contentsOf: fileURL)
      #else
        return UIImage(contentsOfFile: fileURL.path)
      #endif
    }.value

    guard let image else { return nil }
    return await ImageDecodeHelper.decodeForDisplay(image)
  }

  private func loadPosterImageFromAnimatedFile(fileURL: URL) async -> PlatformImage? {
    let image = await Task.detached(priority: .userInitiated) { () -> PlatformImage? in
      AnimatedImageSupport.posterImage(from: fileURL)
    }.value

    guard let image else { return nil }
    return await ImageDecodeHelper.decodeForDisplay(image)
  }

  private func preloadDecodedPageImage(pageIndex: Int) async -> (PlatformImage?, URL?) {
    guard let readerPage = readerPage(at: pageIndex) else {
      return (nil, nil)
    }
    let page = readerPage.page

    guard let sourceFileURL = await getPageImageFileURL(pageIndex: pageIndex) else {
      return (nil, nil)
    }
    guard !Task.isCancelled else { return (nil, nil) }

    let isAnimated = Self.detectAnimatedState(for: page, fileURL: sourceFileURL)
    let animatedSourceFileURL = isAnimated ? sourceFileURL : nil
    if isAnimated {
      if let posterImage = await loadPosterImageFromAnimatedFile(fileURL: sourceFileURL) {
        return (posterImage, animatedSourceFileURL)
      }

      let fallbackImage = await loadImageFromFile(fileURL: sourceFileURL)
      return (fallbackImage, animatedSourceFileURL)
    }

    let preferredFileURL = await preferredDisplayImageFileURL(
      page: page,
      pageID: readerPage.id,
      sourceFileURL: sourceFileURL,
      isAnimated: isAnimated
    )

    if let image = await loadImageFromFile(fileURL: preferredFileURL) {
      return (image, animatedSourceFileURL)
    }

    if preferredFileURL != sourceFileURL {
      logger.debug(
        "⏭️ [Upscale] Fallback to original file for page \(page.number + 1) because @2x decode failed"
      )
      let fallbackImage = await loadImageFromFile(fileURL: sourceFileURL)
      return (fallbackImage, animatedSourceFileURL)
    }

    return (nil, animatedSourceFileURL)
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
      logger.debug("✅ [Upscale] Use cached @2x page \(page.number + 1): \(cachedUpscaledURL.lastPathComponent)")
      return cachedUpscaledURL
    }

    if let existingTask = upscalingTasks[pageID] {
      logger.debug("⏳ [Upscale] Await running upscale task for page \(page.number + 1)")
      if let cachedURL = await existingTask.task.value {
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

    let taskToken = UUID()
    let upscaleTask = Task<URL?, Never>.detached(priority: .userInitiated) {
      [sourceFileURL, upscaledFileURLs, pageNumber] in
      let logger = AppLogger(.reader)

      guard !Task.isCancelled else { return nil }

      if let cachedUpscaledURL = upscaledFileURLs.first(where: { FileManager.default.fileExists(atPath: $0.path) }) {
        logger.debug("✅ [Upscale] Use cached @2x page \(pageNumber + 1): \(cachedUpscaledURL.lastPathComponent)")
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
      guard !Task.isCancelled else { return nil }

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

    upscalingTasks[pageID] = URLLoadTaskRecord(token: taskToken, task: upscaleTask)
    let result = await upscaleTask.value
    removeTrackedURLTaskIfCurrent(for: pageID, token: taskToken, from: &upscalingTasks)
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
        directory.appendingPathComponent(resolvedBaseName).appendingPathExtension(sourceExtension)
      )
    } else {
      candidates.append(directory.appendingPathComponent(resolvedBaseName))
    }

    if sourceExtension != "jpg" && sourceExtension != "jpeg" {
      candidates.append(
        directory.appendingPathComponent(resolvedBaseName).appendingPathExtension("jpg")
      )
    }
    if sourceExtension != "png" {
      candidates.append(
        directory.appendingPathComponent(resolvedBaseName).appendingPathExtension("png")
      )
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

  nonisolated private static func upscaleSkipReasonText(
    _ reason: ReaderUpscaleDecision.SkipReason?
  ) -> String {
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
          "⏭️ [Upscale] Unsupported destination type for \(targetFileURL.lastPathComponent), trying fallback"
        )
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

  private func updateAnimatedPresentation(
    knownAnimatedState: Bool?,
    sourceFileURL: URL?,
    for pageID: ReaderPageID
  ) {
    var didChange = false

    if let knownAnimatedState {
      if animatedPageStates[pageID] != knownAnimatedState {
        animatedPageStates[pageID] = knownAnimatedState
        didChange = true
      }
    } else if animatedPageStates.removeValue(forKey: pageID) != nil {
      didChange = true
    }

    if let sourceFileURL {
      if animatedPageSourceFileURLs[pageID] != sourceFileURL {
        animatedPageSourceFileURLs[pageID] = sourceFileURL
        didChange = true
      }
    } else if animatedPageSourceFileURLs.removeValue(forKey: pageID) != nil {
      didChange = true
    }

    if didChange {
      invalidatePresentation(.pages([pageID]))
    }
  }

  private func prepareAnimatedPagePlaybackURL(pageIndex: Int) async {
    guard pageIndex >= 0 && pageIndex < readerPages.count else { return }
    guard let pageID = readerPageID(forPageIndex: pageIndex) else { return }
    let page = readerPages[pageIndex].page
    guard page.isAnimatedImageCandidate else {
      updateAnimatedPresentation(knownAnimatedState: false, sourceFileURL: nil, for: pageID)
      return
    }

    guard let fileURL = await getPageImageFileURL(pageIndex: pageIndex) else { return }
    let isAnimated = Self.detectAnimatedState(for: page, fileURL: fileURL)
    updateAnimatedPresentation(
      knownAnimatedState: isAnimated,
      sourceFileURL: isAnimated ? fileURL : nil,
      for: pageID
    )
  }

  private func resolvedDownloadURL(for page: BookPage, bookId: String) -> URL? {
    if let url = page.downloadURL {
      return url
    }
    return BookService.shared.getBookPageURL(bookId: bookId, page: page.number)
  }
}
