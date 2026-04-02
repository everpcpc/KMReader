//
// OfflineManager.swift
//
//

import Combine
import Foundation
import OSLog
import UniformTypeIdentifiers
import ZIPFoundation

#if os(iOS)
  import UIKit
#endif

#if os(iOS)
  private typealias BackgroundTaskID = UIBackgroundTaskIdentifier
#else
  private typealias BackgroundTaskID = Int
#endif

/// Simple Sendable struct for download info.
enum DownloadContentKind: Sendable {
  case pages
  case epubWebPub
  case epubDivina
  case pdf
}

struct DownloadInfo: Sendable {
  let bookId: String
  let seriesTitle: String?
  let bookInfo: String
  let kind: DownloadContentKind
}

/// Actor for managing offline book downloads with proper thread isolation.
/// Download status is persisted in SwiftData via KomgaBook.downloadStatus.
/// Progress is tracked via DownloadProgressTracker for UI display.
@globalActor
actor OfflineManager {
  static let shared = OfflineManager()

  private var activeTasks: [String: Task<Void, Never>] = [:]
  private var syncTask: Task<Void, Never>?
  private var syncTaskID: UUID?
  private var isProcessingQueue = false
  private var completedDownloadsSinceLastNotification = 0
  #if os(iOS)
    private var foregroundDownloadInfoByBookId: [String: (instanceId: String, info: DownloadInfo)] = [:]
  #endif

  private let logger = AppLogger(.offline)
  private let pageImageCache = ImageCache()

  private init() {
    #if os(iOS)
      // Schedule callback setup on main actor
      Task { @MainActor in
        await self.setupBackgroundDownloadCallbacks()
      }
    #endif
  }

  #if os(iOS)
    private func setupBackgroundDownloadCallbacks() async {
      let manager = await MainActor.run { BackgroundDownloadManager.shared }

      await MainActor.run {
        manager.onDownloadComplete = { [weak self] bookId, pageNumber, fileURL in
          guard let self = self else { return }
          Task {
            await self.handleBackgroundDownloadComplete(
              bookId: bookId, pageNumber: pageNumber, fileURL: fileURL)
          }
        }

        manager.onDownloadFailed = { [weak self] bookId, pageNumber, error in
          guard let self = self else { return }
          Task {
            await self.handleBackgroundDownloadFailed(
              bookId: bookId, pageNumber: pageNumber, error: error)
          }
        }

        manager.onAllDownloadsComplete = { [weak self] bookId in
          guard let self = self else { return }
          Task {
            await self.handleAllBackgroundDownloadsComplete(bookId: bookId)
          }
        }
      }
    }
  #endif

  private static let directoryName = "OfflineBooks"
  private static let epubFileName = "book.epub"
  private static let pdfFileName = "book.pdf"
  private static let pdfPreparationStampFileName = ".pdf-prepared.stamp"
  private nonisolated static let pdfPreparationStampVersion = "prepared-v4"

  nonisolated static func pdfPreparationCompletionFlag(
    renderQuality: PdfOfflineRenderQuality
  ) -> String {
    "\(pdfPreparationStampVersion)-\(renderQuality.rawValue)"
  }

  // MARK: - Paths

  /// Base directory for all offline books.
  private static func baseDirectory() -> URL {
    let appSupport =
      FileManager.default.urls(
        for: .applicationSupportDirectory, in: .userDomainMask
      ).first ?? FileManager.default.temporaryDirectory
    ensureDirectoryExists(at: appSupport)
    let base = appSupport.appendingPathComponent(directoryName, isDirectory: true)
    migrateLegacyDirectoryIfNeeded(to: base)
    ensureDirectoryExists(at: base)
    excludeFromBackupIfNeeded(at: base)
    return base
  }

  /// Namespaced directory for a specific instance's offline books.
  private static func offlineDirectory(for instanceId: String) -> URL {
    let sanitized = instanceId.isEmpty ? "default" : instanceId
    let url = baseDirectory().appendingPathComponent(sanitized, isDirectory: true)
    ensureDirectoryExists(at: url)
    excludeFromBackupIfNeeded(at: url)
    return url
  }

  /// Remove all offline downloads for a specific instance.
  nonisolated static func removeOfflineData(for instanceId: String) {
    let url = offlineDirectory(for: instanceId)
    try? FileManager.default.removeItem(at: url)
  }

  private func bookDirectory(instanceId: String, bookId: String) -> URL {
    let url = Self.offlineDirectory(for: instanceId)
      .appendingPathComponent(bookId, isDirectory: true)
    Self.ensureDirectoryExists(at: url)
    Self.excludeFromBackupIfNeeded(at: url)
    return url
  }

  private func webPubRootURL(bookDir: URL) -> URL {
    let url = bookDir.appendingPathComponent("webpub", isDirectory: true)
    Self.ensureDirectoryExists(at: url)
    Self.excludeFromBackupIfNeeded(at: url)
    return url
  }

  private static func webPubResourceURL(root: URL, href: String) -> URL {
    let relativePath = webPubRelativePath(from: href)
    return root.appendingPathComponent(relativePath, isDirectory: false)
  }

  private static func webPubRelativePath(from href: String) -> String {
    if let resourcePath = manifestResourcePath(from: href),
      let normalizedPath = normalizeArchivePath(resourcePath)
    {
      let components = normalizedPath.split(separator: "/").map(String.init)
      let sanitized =
        components.enumerated().map { index, component in
          let fallback = index == components.count - 1 ? "resource" : "dir"
          return sanitizePathComponent(component, fallback: fallback)
        }
      if !sanitized.isEmpty {
        return sanitized.joined(separator: "/")
      }
    }

    return legacyWebPubRelativePath(from: href)
  }

  private static func legacyWebPubRelativePath(from href: String) -> String {
    let cleaned = href.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !cleaned.isEmpty else {
      return FileNameHelper.sanitizedFileName("resource", defaultBaseName: "resource")
    }

    let hrefURL = URL(string: cleaned)
    let rawPath = hrefURL?.path.isEmpty == false ? hrefURL!.path : cleaned
    let trimmedPath = rawPath.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    let components = trimmedPath.split(separator: "/").map(String.init)

    var sanitized = components.enumerated().compactMap { index, component -> String? in
      if component == "." || component == ".." {
        return nil
      }
      let fallback = index == components.count - 1 ? "resource" : "dir"
      return sanitizePathComponent(component, fallback: fallback)
    }

    if sanitized.isEmpty {
      return FileNameHelper.sanitizedFileName("resource", defaultBaseName: "resource")
    }

    let query = URLComponents(string: cleaned)?.query
    if let query, !query.isEmpty {
      let suffix = "--q-" + sanitizePathComponent(query, fallback: "q")
      sanitized[sanitized.count - 1] += suffix
    }

    return sanitized.joined(separator: "/")
  }

  private static func sanitizePathComponent(_ value: String, fallback: String) -> String {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    let invalidCharacters = CharacterSet(charactersIn: "\\/:*?\"<>|")
    var sanitized = trimmed.components(separatedBy: invalidCharacters).joined(separator: "-")
    sanitized = sanitized.replacingOccurrences(of: " ", with: "-")

    while sanitized.contains("--") {
      sanitized = sanitized.replacingOccurrences(of: "--", with: "-")
    }

    if sanitized.isEmpty {
      return fallback
    }

    return sanitized
  }

  // MARK: - Public API

  /// Get the download status of a book from SwiftData.
  func getDownloadStatus(bookId: String) async -> DownloadStatus {
    (try? await DatabaseOperator.database().getDownloadStatus(bookId: bookId)) ?? .notDownloaded
  }

  /// Check if a book is downloaded.
  func isBookDownloaded(bookId: String) async -> Bool {
    if case .downloaded = await getDownloadStatus(bookId: bookId) {
      return true
    }
    return false
  }

  func getOfflineWebPubRootURL(instanceId: String, bookId: String) async -> URL? {
    guard await isBookDownloaded(bookId: bookId) else { return nil }
    let bookDir = bookDirectory(instanceId: instanceId, bookId: bookId)
    return webPubRootURL(bookDir: bookDir)
  }

  func cachedOfflineWebPubResourceURL(
    instanceId: String,
    bookId: String,
    href: String
  ) async -> URL? {
    guard await isBookDownloaded(bookId: bookId) else { return nil }
    let bookDir = bookDirectory(instanceId: instanceId, bookId: bookId)
    let root = webPubRootURL(bookDir: bookDir)
    let destination = Self.webPubResourceURL(root: root, href: href)
    if FileManager.default.fileExists(atPath: destination.path) {
      return destination
    }

    let legacyDestination = root.appendingPathComponent(
      Self.legacyWebPubRelativePath(from: href),
      isDirectory: false
    )
    if legacyDestination.path != destination.path,
      FileManager.default.fileExists(atPath: legacyDestination.path)
    {
      return legacyDestination
    }

    return nil
  }

  func toggleDownload(instanceId: String, info: DownloadInfo) async {
    let status = await getDownloadStatus(bookId: info.bookId)
    switch status {
    case .downloaded:
      await deleteBook(instanceId: instanceId, bookId: info.bookId)
    case .pending:
      await cancelDownload(bookId: info.bookId, instanceId: instanceId)
    case .notDownloaded, .failed:
      try? await DatabaseOperator.database().updateBookDownloadStatus(
        bookId: info.bookId,
        instanceId: instanceId,
        status: .pending,
        downloadAt: .now
      )
      try? await DatabaseOperator.database().commit()
      await refreshQueueStatus(instanceId: instanceId)
      await syncDownloadQueue(instanceId: instanceId)
    }
  }

  func retryDownload(instanceId: String, bookId: String) async {
    try? await DatabaseOperator.database().updateBookDownloadStatus(
      bookId: bookId,
      instanceId: instanceId,
      status: .pending,
      downloadAt: .now
    )
    try? await DatabaseOperator.database().commit()
    await refreshQueueStatus(instanceId: instanceId)
    await syncDownloadQueue(instanceId: instanceId)
  }

  func deleteBook(
    instanceId: String, bookId: String, commit: Bool = true, syncSeriesStatus: Bool = true
  ) async {
    await cancelDownload(
      bookId: bookId, instanceId: instanceId, commit: false, syncSeriesStatus: syncSeriesStatus)
    let dir = bookDirectory(instanceId: instanceId, bookId: bookId)

    // Update SwiftData
    try? await DatabaseOperator.database().updateBookDownloadStatus(
      bookId: bookId, instanceId: instanceId, status: .notDownloaded,
      syncSeriesStatus: syncSeriesStatus
    )
    if commit {
      try? await DatabaseOperator.database().commit()
      await refreshQueueStatus(instanceId: instanceId)
    }

    // Then delete files
    Task.detached { [logger] in
      do {
        if FileManager.default.fileExists(atPath: dir.path) {
          try FileManager.default.removeItem(at: dir)
        }
        logger.info("🗑️ Deleted offline book: \(bookId)")
      } catch {
        logger.error("❌ Failed to delete book \(bookId): \(error)")
      }
    }

    #if os(iOS) || os(macOS)
      SpotlightIndexService.removeBook(bookId: bookId, instanceId: instanceId)
    #endif
  }

  /// Delete a book manually, setting series policy to manual first to prevent automatic re-download.
  func deleteBookManually(seriesId: String, instanceId: String, bookId: String) async {
    try? await DatabaseOperator.database().updateSeriesOfflinePolicy(
      seriesId: seriesId,
      instanceId: instanceId,
      policy: .manual,
      syncSeriesStatus: false
    )
    await deleteBook(instanceId: instanceId, bookId: bookId)
  }

  /// Delete multiple books manually, setting series policy to manual first to prevent automatic re-download.
  func deleteBooksManually(seriesId: String, instanceId: String, bookIds: [String]) async {
    try? await DatabaseOperator.database().updateSeriesOfflinePolicy(
      seriesId: seriesId,
      instanceId: instanceId,
      policy: .manual,
      syncSeriesStatus: false
    )
    for bookId in bookIds {
      await deleteBook(
        instanceId: instanceId, bookId: bookId, commit: false, syncSeriesStatus: false)
    }
    try? await DatabaseOperator.database().syncSeriesDownloadStatus(
      seriesId: seriesId, instanceId: instanceId)
    // Also sync readlists containing these books
    try? await DatabaseOperator.database().syncReadListsContainingBooks(
      bookIds: bookIds, instanceId: instanceId)
    try? await DatabaseOperator.database().commit()
    await refreshQueueStatus(instanceId: instanceId)
  }

  /// Delete all downloaded books for the current instance.
  func deleteAllDownloadedBooks() async {
    let instanceId = AppConfig.current.instanceId
    let books =
      (try? await DatabaseOperator.database().fetchDownloadedBooks(instanceId: instanceId)) ?? []

    // Group by series to update policies
    let seriesIds = Set(books.map { $0.seriesId })
    for seriesId in seriesIds {
      try? await DatabaseOperator.database().updateSeriesOfflinePolicy(
        seriesId: seriesId,
        instanceId: instanceId,
        policy: .manual,
        syncSeriesStatus: false
      )
    }

    for book in books {
      await deleteBook(
        instanceId: instanceId, bookId: book.id, commit: false, syncSeriesStatus: false)
    }

    for seriesId in seriesIds {
      try? await DatabaseOperator.database().syncSeriesDownloadStatus(
        seriesId: seriesId, instanceId: instanceId)
    }
    // Also sync readlists containing these books
    try? await DatabaseOperator.database().syncReadListsContainingBooks(
      bookIds: books.map { $0.id }, instanceId: instanceId)
    try? await DatabaseOperator.database().commit()
    await refreshQueueStatus(instanceId: instanceId)

    #if os(iOS) || os(macOS)
      SpotlightIndexService.removeAllItems()
    #endif
  }

  /// Delete all read (completed) downloaded books for the current instance.
  func deleteReadBooks() async {
    let instanceId = AppConfig.current.instanceId
    let readBooks =
      (try? await DatabaseOperator.database().fetchReadBooksEligibleForAutoDelete(
        instanceId: instanceId
      )) ?? []

    if readBooks.isEmpty { return }

    // Group by series to update policies
    let seriesIds = Set(readBooks.map { $0.seriesId })
    for seriesId in seriesIds {
      try? await DatabaseOperator.database().updateSeriesOfflinePolicy(
        seriesId: seriesId,
        instanceId: instanceId,
        policy: .manual,
        syncSeriesStatus: false
      )
    }

    for book in readBooks {
      await deleteBook(
        instanceId: instanceId, bookId: book.id, commit: false, syncSeriesStatus: false)
    }

    for seriesId in seriesIds {
      try? await DatabaseOperator.database().syncSeriesDownloadStatus(
        seriesId: seriesId, instanceId: instanceId)
    }
    // Also sync readlists containing these books
    try? await DatabaseOperator.database().syncReadListsContainingBooks(
      bookIds: readBooks.map { $0.id }, instanceId: instanceId)
    try? await DatabaseOperator.database().commit()
    await refreshQueueStatus(instanceId: instanceId)
  }

  /// Cleanup orphaned offline files that no longer have corresponding SwiftData entries.
  /// Returns the number of orphaned directories deleted and total bytes freed.
  func cleanupOrphanedFiles() async -> (deletedCount: Int, bytesFreed: Int64) {
    let instanceId = AppConfig.current.instanceId
    let offlineDir = Self.offlineDirectory(for: instanceId)
    let fm = FileManager.default

    guard let contents = try? fm.contentsOfDirectory(atPath: offlineDir.path) else {
      return (0, 0)
    }

    // Get all downloaded book IDs from SwiftData
    let downloadedBooks =
      (try? await DatabaseOperator.database().fetchDownloadedBooks(instanceId: instanceId)) ?? []
    let downloadedBookIds = Set(downloadedBooks.map { $0.id })

    var deletedCount = 0
    var bytesFreed: Int64 = 0

    for bookId in contents {
      let bookDir = offlineDir.appendingPathComponent(bookId)

      // Skip if not a directory
      var isDir: ObjCBool = false
      guard fm.fileExists(atPath: bookDir.path, isDirectory: &isDir), isDir.boolValue else {
        continue
      }

      // Check if this book is still in downloaded state in SwiftData
      if !downloadedBookIds.contains(bookId) {
        // Orphaned directory - calculate size and delete
        if let size = try? Self.calculateDirectorySize(bookDir) {
          bytesFreed += size
        }

        do {
          try fm.removeItem(at: bookDir)
          deletedCount += 1
          logger.info("🗑️ Cleaned up orphaned offline directory: \(bookId)")
        } catch {
          logger.error("❌ Failed to cleanup orphaned directory \(bookId): \(error)")
        }
      }
    }

    if deletedCount > 0 {
      logger.info(
        "✅ Cleanup complete: \(deletedCount) orphaned directories, \(bytesFreed) bytes freed")
    }

    return (deletedCount, bytesFreed)
  }

  func cancelDownload(
    bookId: String, instanceId: String? = nil, commit: Bool = true, syncSeriesStatus: Bool = true
  ) async {
    removeActiveTask(bookId)
    let resolvedInstanceId = instanceId ?? AppConfig.current.instanceId
    try? await DatabaseOperator.database().updateBookDownloadStatus(
      bookId: bookId, instanceId: resolvedInstanceId, status: .notDownloaded,
      syncSeriesStatus: syncSeriesStatus
    )
    if commit {
      try? await DatabaseOperator.database().commit()
      await refreshQueueStatus(instanceId: resolvedInstanceId)
    }
  }

  /// Cancel all active downloads (used during cleanup).
  func cancelAllDownloads() async {
    let instanceId = AppConfig.current.instanceId
    let bookIds = Array(activeTasks.keys)
    for (bookId, task) in activeTasks {
      task.cancel()
      try? await DatabaseOperator.database().updateBookDownloadStatus(
        bookId: bookId, instanceId: instanceId, status: .notDownloaded
      )
      try? await DatabaseOperator.database().commit()
    }
    activeTasks.removeAll()
    await MainActor.run {
      for bookId in bookIds {
        DownloadProgressTracker.shared.clearProgress(bookId: bookId)
      }
      DownloadProgressTracker.shared.finishDownload()
    }
    #if os(iOS)
      await LiveActivityManager.shared.endActivity()
    #endif
    await refreshQueueStatus(instanceId: instanceId)
  }

  func retryFailedDownloads(instanceId: String) async {
    try? await DatabaseOperator.database().retryFailedBooks(instanceId: instanceId)
    try? await DatabaseOperator.database().commit()
    await refreshQueueStatus(instanceId: instanceId)
    await syncDownloadQueue(instanceId: instanceId)
  }

  func cancelFailedDownloads(instanceId: String) async {
    try? await DatabaseOperator.database().cancelFailedBooks(instanceId: instanceId)
    try? await DatabaseOperator.database().commit()
    await refreshQueueStatus(instanceId: instanceId)
  }

  /// Trigger the download queue processing in the background.
  /// - Parameter restart: If true, cancels any pending debounce and runs immediately.
  nonisolated func triggerSync(instanceId: String, restart: Bool = false) {
    Task {
      await performDebouncedSync(instanceId: instanceId, restart: restart)
    }
  }

  private func performDebouncedSync(instanceId: String, restart: Bool) async {
    syncTask?.cancel()

    let currentID = UUID()
    syncTaskID = currentID

    syncTask = Task {
      if !restart {
        try? await Task.sleep(for: .seconds(2))
      }

      guard !Task.isCancelled else { return }

      // If we are still the current task (didn't get replaced during sleep),
      // we clear the reference so future triggers don't cancel us while we run.
      if syncTaskID == currentID {
        syncTask = nil
        syncTaskID = nil
      }

      await syncDownloadQueue(instanceId: instanceId)
    }
  }

  private func startBackgroundTask() async -> BackgroundTaskID {
    #if os(iOS)
      return await MainActor.run {
        UIApplication.shared.beginBackgroundTask(withName: "OfflineMetadataFetch") {
          // If the task expires, there's not much we can do but log it
        }
      }
    #else
      return 0
    #endif
  }

  private func endBackgroundTask(_ identifier: BackgroundTaskID) async {
    #if os(iOS)
      if identifier != .invalid {
        await MainActor.run {
          UIApplication.shared.endBackgroundTask(identifier)
        }
      }
    #endif
  }

  private func syncDownloadQueue(instanceId: String) async {
    // Check if offline
    guard !AppConfig.isOffline else { return }

    // Check if paused
    guard !AppConfig.offlinePaused else { return }
    guard !isProcessingQueue else { return }

    // Only allow one download at a time
    guard activeTasks.isEmpty else { return }

    let backgroundTaskId = await startBackgroundTask()
    defer {
      Task {
        await endBackgroundTask(backgroundTaskId)
      }
    }

    isProcessingQueue = true
    defer { isProcessingQueue = false }

    // Auto-delete read books if enabled
    if AppConfig.offlineAutoDeleteRead {
      await deleteReadBooks()
    }

    await syncMissingOfflineEpubProgressions(instanceId: instanceId)

    let pending =
      (try? await DatabaseOperator.database().fetchPendingBooks(instanceId: instanceId)) ?? []

    guard let nextBook = pending.first else {
      if completedDownloadsSinceLastNotification > 0 {
        completedDownloadsSinceLastNotification = 0
        let failedCount =
          (try? await DatabaseOperator.database().fetchFailedBooksCount(
            instanceId: instanceId
          )) ?? 0
        if failedCount == 0 {
          await MainActor.run {
            ErrorManager.shared.notify(
              message: String(localized: "notification.offline.tasksCompleted")
            )
          }
        }
      }
      return
    }

    // Proceed to download even if it's read, as it was likely manually requested or reader is opening it.
    await startDownload(instanceId: instanceId, info: nextBook.downloadInfo)
  }

  private func syncMissingOfflineEpubProgressions(instanceId: String) async {
    let bookIds =
      (try? await DatabaseOperator.database().fetchOfflineEpubBookIdsMissingProgression(
        instanceId: instanceId
      )) ?? []
    guard !bookIds.isEmpty else { return }

    logger.info(
      "📥 Syncing missing EPUB progression for \(bookIds.count) offline books with non-zero progress"
    )

    var syncedCount = 0
    var failedCount = 0

    for bookId in bookIds {
      let remoteState = await BookService.shared.fetchRemoteWebPubProgression(bookId: bookId)

      switch remoteState {
      case .available(let progression):
        try? await DatabaseOperator.database().updateBookEpubProgression(
          bookId: bookId,
          progression: progression
        )
        syncedCount += 1
      case .missing:
        try? await DatabaseOperator.database().updateBookEpubProgression(
          bookId: bookId,
          progression: nil
        )
        syncedCount += 1
        logger.info(
          "⏭️ Marked missing remote EPUB progression as handled for offline book \(bookId)"
        )
      case .retryableFailure(let error):
        failedCount += 1
        logger.warning(
          "⚠️ Failed to sync missing EPUB progression for offline book \(bookId): \(error.localizedDescription)"
        )
      case .invalidPayload(let error):
        try? await DatabaseOperator.database().updateBookEpubProgression(
          bookId: bookId,
          progression: nil
        )
        syncedCount += 1
        logger.warning(
          "⏭️ Ignoring non-retryable remote EPUB progression payload for offline book \(bookId): \(error.localizedDescription)"
        )
      }
    }

    if syncedCount > 0 {
      try? await DatabaseOperator.database().commit()
    }

    logger.info(
      "✅ Finished syncing missing EPUB progression for offline books: synced=\(syncedCount), failed=\(failedCount)"
    )
  }

  private func startDownload(instanceId: String, info: DownloadInfo) async {
    guard activeTasks[info.bookId] == nil else { return }

    logger.info("📥 Enqueue download: \(info.bookId)")
    // Initialize progress (status stays as pending during download)
    await MainActor.run {
      DownloadProgressTracker.shared.startDownload(bookName: info.bookInfo)
      DownloadProgressTracker.shared.updateProgress(bookId: info.bookId, value: 0.0)
    }

    let bookDir = bookDirectory(instanceId: instanceId, bookId: info.bookId)

    #if os(iOS)
      // Use background downloads on iOS for all content kinds.
      await startBackgroundDownload(instanceId: instanceId, info: info, bookDir: bookDir)
    #else
      // Use in-process downloads on macOS/tvOS
      await startForegroundDownload(instanceId: instanceId, info: info, bookDir: bookDir)
    #endif
  }

  #if os(iOS)
    private func startBackgroundDownload(
      instanceId: String, info: DownloadInfo, bookDir: URL
    ) async {
      logger.info("⬇️ Starting background download for book: \(info.bookInfo) (\(info.bookId))")

      do {
        // Get pending count and failed count for Live Activity
        let pendingBooks =
          (try? await DatabaseOperator.database().fetchPendingBooks(instanceId: instanceId)) ?? []
        let failedCount =
          (try? await DatabaseOperator.database().fetchFailedBooksCount(
            instanceId: instanceId
          )) ?? 0

        // Start or update Live Activity for download progress
        await LiveActivityManager.shared.startActivity(
          seriesTitle: info.seriesTitle,
          bookInfo: info.bookInfo,
          totalBooks: pendingBooks.count + 1,
          pendingCount: pendingBooks.count,
          failedCount: failedCount
        )

        // First, fetch and save metadata (this needs to happen before background download)
        let pages = try await BookService.shared.getBookPages(id: info.bookId)
        try? await DatabaseOperator.database().updateBookPages(bookId: info.bookId, pages: pages)
        try? await DatabaseOperator.database().commit()

        // Save TOC if available
        if let manifest = try? await BookService.shared.getBookManifest(id: info.bookId) {
          let toc = await ReaderManifestService(bookId: info.bookId).parseTOC(manifest: manifest)
          try? await DatabaseOperator.database().updateBookTOC(bookId: info.bookId, toc: toc)
          try? await DatabaseOperator.database().commit()
        }

        switch info.kind {
        case .epubWebPub:
          let webPubManifest = try await BookService.shared.getBookWebPubManifest(bookId: info.bookId)
          try? await DatabaseOperator.database().updateBookWebPubManifest(
            bookId: info.bookId,
            manifest: webPubManifest
          )
          try? await DatabaseOperator.database().commit()
          try await scheduleBackgroundEpubDownload(
            instanceId: instanceId,
            info: info,
            bookDir: bookDir,
            manifest: webPubManifest
          )
        case .pdf:
          try await scheduleBackgroundPdfDownload(
            instanceId: instanceId,
            info: info,
            bookDir: bookDir
          )
        case .pages, .epubDivina:
          try await scheduleBackgroundPageDownloads(
            instanceId: instanceId,
            info: info,
            bookDir: bookDir,
            pages: pages,
            pendingCount: pendingBooks.count,
            failedCount: failedCount
          )
        }
      } catch {
        logger.error("❌ Failed to start background download for \(info.bookId): \(error)")
        await BackgroundDownloadManager.shared.cancelDownloads(forBookId: info.bookId)
        clearBackgroundDownloadContext(bookId: info.bookId)
        removeActiveTask(info.bookId)
        try? await DatabaseOperator.database().updateBookDownloadStatus(
          bookId: info.bookId,
          instanceId: instanceId,
          status: .failed(error: error.localizedDescription)
        )
        try? await DatabaseOperator.database().commit()
        await refreshQueueStatus(instanceId: instanceId)
        await syncDownloadQueue(instanceId: instanceId)
      }
    }

    private func scheduleBackgroundPageDownloads(
      instanceId: String,
      info: DownloadInfo,
      bookDir: URL,
      pages: [BookPage],
      pendingCount: Int,
      failedCount: Int
    ) async throws {
      let totalTaskCount = pages.count
      guard totalTaskCount > 0 else {
        await MainActor.run {
          DownloadProgressTracker.shared.updateProgress(bookId: info.bookId, value: 1.0)
        }
        await finalizeDownload(instanceId: instanceId, bookId: info.bookId, bookDir: bookDir)
        await syncDownloadQueue(instanceId: instanceId)
        return
      }

      let serverURL = await MainActor.run { AppConfig.current.serverURL }
      var pagesToDownload: [BookPage] = []

      for page in pages {
        let ext = page.detectedUTType?.preferredFilenameExtension ?? "jpg"
        let destination = bookDir.appendingPathComponent("page-\(page.number).\(ext)")

        if FileManager.default.fileExists(atPath: destination.path) {
          continue
        }
        if await copyCachedPageIfAvailable(
          bookId: info.bookId,
          page: page,
          destination: destination
        ) {
          continue
        }
        pagesToDownload.append(page)
      }

      let completedTaskCount = totalTaskCount - pagesToDownload.count
      if pagesToDownload.isEmpty {
        logger.info("✅ All pages already downloaded for book: \(info.bookId)")
        await MainActor.run {
          DownloadProgressTracker.shared.updateProgress(bookId: info.bookId, value: 1.0)
        }
        await finalizeDownload(instanceId: instanceId, bookId: info.bookId, bookDir: bookDir)
        await syncDownloadQueue(instanceId: instanceId)
        return
      }

      registerBackgroundDownloadContext(
        bookId: info.bookId,
        instanceId: instanceId,
        seriesTitle: info.seriesTitle,
        bookInfo: info.bookInfo,
        kind: info.kind,
        totalTasks: totalTaskCount,
        completedTasks: completedTaskCount
      )

      if completedTaskCount > 0 {
        let initialProgress = Double(completedTaskCount) / Double(totalTaskCount)
        await MainActor.run {
          DownloadProgressTracker.shared.updateProgress(bookId: info.bookId, value: initialProgress)
        }
        await LiveActivityManager.shared.updateActivity(
          seriesTitle: info.seriesTitle,
          bookInfo: info.bookInfo,
          progress: initialProgress,
          pendingCount: pendingCount,
          failedCount: failedCount
        )
      }

      for page in pagesToDownload {
        guard
          let downloadURL = URL(
            string: serverURL + "/api/v1/books/\(info.bookId)/pages/\(page.number)")
        else {
          throw AppErrorType.invalidFileURL(url: "/api/v1/books/\(info.bookId)/pages/\(page.number)")
        }

        let ext = page.detectedUTType?.preferredFilenameExtension ?? "jpg"
        let destinationPath = bookDir.appendingPathComponent("page-\(page.number).\(ext)").path

        await MainActor.run {
          BackgroundDownloadManager.shared.downloadPage(
            bookId: info.bookId,
            instanceId: instanceId,
            pageNumber: page.number,
            url: downloadURL,
            destinationPath: destinationPath
          )
        }
      }
    }

    private func scheduleBackgroundPdfDownload(
      instanceId: String,
      info: DownloadInfo,
      bookDir: URL
    ) async throws {
      let destinationURL = bookDir.appendingPathComponent(Self.pdfFileName)
      if FileManager.default.fileExists(atPath: destinationURL.path) {
        logger.info("✅ Background PDF already exists for book: \(info.bookId)")
        await MainActor.run {
          DownloadProgressTracker.shared.updateProgress(bookId: info.bookId, value: 1.0)
        }
        await finalizeDownload(instanceId: instanceId, bookId: info.bookId, bookDir: bookDir)
        await syncDownloadQueue(instanceId: instanceId)
        return
      }

      let serverURL = await MainActor.run { AppConfig.current.serverURL }
      guard let downloadURL = URL(string: serverURL + "/api/v1/books/\(info.bookId)/file") else {
        throw AppErrorType.invalidFileURL(url: "/api/v1/books/\(info.bookId)/file")
      }

      registerBackgroundDownloadContext(
        bookId: info.bookId,
        instanceId: instanceId,
        seriesTitle: info.seriesTitle,
        bookInfo: info.bookInfo,
        kind: info.kind,
        totalTasks: 1,
        completedTasks: 0
      )

      await MainActor.run {
        BackgroundDownloadManager.shared.downloadFile(
          bookId: info.bookId,
          instanceId: instanceId,
          url: downloadURL,
          destinationPath: destinationURL.path,
          reportByteProgress: true
        )
      }
    }

    private func scheduleBackgroundEpubDownload(
      instanceId: String,
      info: DownloadInfo,
      bookDir: URL,
      manifest: WebPubPublication
    ) async throws {
      let destinationURL = bookDir.appendingPathComponent(Self.epubFileName)
      if FileManager.default.fileExists(atPath: destinationURL.path) {
        logger.info("✅ Background EPUB already exists for book: \(info.bookId)")
        try extractEpubToWebPub(
          epubFile: destinationURL, bookId: info.bookId, manifest: manifest, bookDir: bookDir)
        try? FileManager.default.removeItem(at: destinationURL)
        await MainActor.run {
          DownloadProgressTracker.shared.updateProgress(bookId: info.bookId, value: 1.0)
        }
        await finalizeDownload(instanceId: instanceId, bookId: info.bookId, bookDir: bookDir)
        await syncDownloadQueue(instanceId: instanceId)
        return
      }

      let serverURL = await MainActor.run { AppConfig.current.serverURL }
      guard let downloadURL = URL(string: serverURL + "/api/v1/books/\(info.bookId)/file") else {
        throw AppErrorType.invalidFileURL(url: "/api/v1/books/\(info.bookId)/file")
      }

      registerBackgroundDownloadContext(
        bookId: info.bookId,
        instanceId: instanceId,
        seriesTitle: info.seriesTitle,
        bookInfo: info.bookInfo,
        kind: info.kind,
        totalTasks: 1,
        completedTasks: 0
      )

      await MainActor.run {
        BackgroundDownloadManager.shared.downloadEpub(
          bookId: info.bookId,
          instanceId: instanceId,
          url: downloadURL,
          destinationPath: destinationURL.path
        )
      }
    }

    private func registerBackgroundDownloadContext(
      bookId: String,
      instanceId: String,
      seriesTitle: String?,
      bookInfo: String,
      kind: DownloadContentKind,
      totalTasks: Int,
      completedTasks: Int
    ) {
      backgroundDownloadInfo[bookId] = (
        instanceId: instanceId,
        seriesTitle: seriesTitle,
        bookInfo: bookInfo,
        kind: kind
      )
      backgroundDownloadTotalTasks[bookId] = totalTasks
      backgroundDownloadCompletedTasks[bookId] = min(max(completedTasks, 0), totalTasks)

      activeTasks[bookId] = Task {
        // Keep a placeholder task so queue state remains "active" until background callbacks finish.
        try? await Task.sleep(nanoseconds: UInt64.max)
      }
    }

    private func clearBackgroundDownloadContext(bookId: String) {
      backgroundDownloadInfo.removeValue(forKey: bookId)
      backgroundDownloadTotalTasks.removeValue(forKey: bookId)
      backgroundDownloadCompletedTasks.removeValue(forKey: bookId)
      backgroundDownloadFinalizingBooks.remove(bookId)
    }
  #endif

  private func startForegroundDownload(
    instanceId: String, info: DownloadInfo, bookDir: URL
  ) async {
    #if os(iOS)
      foregroundDownloadInfoByBookId[info.bookId] = (instanceId: instanceId, info: info)
      let pendingBooks =
        (try? await DatabaseOperator.database().fetchPendingBooks(instanceId: instanceId)) ?? []
      let failedCount =
        (try? await DatabaseOperator.database().fetchFailedBooksCount(instanceId: instanceId))
        ?? 0
      await LiveActivityManager.shared.startActivity(
        seriesTitle: info.seriesTitle,
        bookInfo: info.bookInfo,
        totalBooks: pendingBooks.count + 1,
        pendingCount: pendingBooks.count,
        failedCount: failedCount
      )
    #endif

    activeTasks[info.bookId] = Task { [weak self, logger] in
      guard let self else { return }
      do {
        logger.info("⬇️ Starting download for book: \(info.bookInfo) (\(info.bookId))")

        switch info.kind {
        case .epubWebPub:
          try await downloadEpub(bookId: info.bookId, to: bookDir)
        case .pdf:
          try await downloadPdfFile(bookId: info.bookId, to: bookDir)
        case .pages, .epubDivina:
          try await downloadPages(bookId: info.bookId, to: bookDir)
        }

        // Mark complete in SwiftData
        await finalizeDownload(
          instanceId: instanceId,
          bookId: info.bookId,
          bookDir: bookDir
        )
        #if os(iOS)
          await self.finishForegroundLiveActivity(bookId: info.bookId, instanceId: instanceId)
        #endif
        logger.info("✅ Download complete for book: \(info.bookId)")

        // Trigger next download
        await syncDownloadQueue(instanceId: instanceId)

      } catch {
        // Cleanup on failure
        try? FileManager.default.removeItem(at: bookDir)
        var shouldTriggerNextDownload = true

        if Task.isCancelled {
          logger.info("⛔ Download cancelled for book: \(info.bookId)")
        } else {
          let shouldKeepPending = await self.shouldKeepPendingAfterNetworkFailure(error)
          if shouldKeepPending {
            // Keep status as pending so foreground retry can continue later.
            logger.info("⚠️ Download paused due to transient network issue: \(info.bookId)")
            shouldTriggerNextDownload = AppConfig.isOffline
          } else {
            logger.error("❌ Download failed for book \(info.bookId): \(error)")
            try? await DatabaseOperator.database().updateBookDownloadStatus(
              bookId: info.bookId,
              instanceId: instanceId,
              status: .failed(error: error.localizedDescription)
            )
            try? await DatabaseOperator.database().commit()
            await self.refreshQueueStatus(instanceId: instanceId)
          }
        }
        await removeActiveTask(info.bookId)
        #if os(iOS)
          await self.finishForegroundLiveActivity(bookId: info.bookId, instanceId: instanceId)
        #endif

        // Trigger next download even on failure or cancellation
        if shouldTriggerNextDownload {
          await syncDownloadQueue(instanceId: instanceId)
        }
      }
    }
  }

  func cancelDownload(bookId: String) async {
    let instanceId = AppConfig.current.instanceId
    await cancelDownload(bookId: bookId, instanceId: instanceId)
  }

  // MARK: - Accessors for Reader

  func getOfflinePageImageURL(
    instanceId: String, bookId: String, pageNumber: Int, fileExtension: String
  ) async -> URL? {
    guard await isBookDownloaded(bookId: bookId) else { return nil }
    let dir = bookDirectory(instanceId: instanceId, bookId: bookId)

    let file = dir.appendingPathComponent("page-\(pageNumber).\(fileExtension)")
    if FileManager.default.fileExists(atPath: file.path) {
      return file
    }
    return nil
  }

  func storeOfflinePageImage(
    instanceId: String,
    bookId: String,
    pageNumber: Int,
    fileExtension: String,
    data: Data
  ) async -> URL? {
    guard await isBookDownloaded(bookId: bookId) else { return nil }
    let dir = bookDirectory(instanceId: instanceId, bookId: bookId)
    let file = dir.appendingPathComponent("page-\(pageNumber).\(fileExtension)")

    if FileManager.default.fileExists(atPath: file.path) {
      return file
    }

    do {
      try data.write(to: file)
      Self.excludeFromBackupIfNeeded(at: file)
      return file
    } catch {
      logger.error(
        "❌ Failed to store offline page image for book \(bookId) page \(pageNumber): \(error)")
      return nil
    }
  }

  func clearOfflinePageImages(instanceId: String, bookId: String) async {
    guard await isBookDownloaded(bookId: bookId) else { return }
    let dir = bookDirectory(instanceId: instanceId, bookId: bookId)

    guard
      let fileURLs = try? FileManager.default.contentsOfDirectory(
        at: dir,
        includingPropertiesForKeys: nil,
        options: [.skipsHiddenFiles]
      )
    else {
      return
    }

    for fileURL in fileURLs where fileURL.lastPathComponent.hasPrefix("page-") {
      do {
        try FileManager.default.removeItem(at: fileURL)
      } catch {
        logger.error("❌ Failed to remove offline page asset \(fileURL.lastPathComponent): \(error)")
      }
    }
  }

  func refreshDownloadedBookSize(instanceId: String, bookId: String) async {
    guard await isBookDownloaded(bookId: bookId) else { return }
    let bookDir = bookDirectory(instanceId: instanceId, bookId: bookId)
    guard let size = try? Self.calculateDirectorySize(bookDir) else { return }

    try? await DatabaseOperator.database().updateBookDownloadStatus(
      bookId: bookId,
      instanceId: instanceId,
      status: .downloaded,
      downloadedSize: size
    )
    try? await DatabaseOperator.database().commit()
  }

  func readOfflinePDFPreparationStamp(instanceId: String, bookId: String) async -> String? {
    guard await isBookDownloaded(bookId: bookId) else { return nil }
    let file = bookDirectory(instanceId: instanceId, bookId: bookId).appendingPathComponent(
      Self.pdfPreparationStampFileName
    )
    guard FileManager.default.fileExists(atPath: file.path) else { return nil }
    guard let data = try? Data(contentsOf: file) else { return nil }
    return String(data: data, encoding: .utf8)?
      .trimmingCharacters(in: .whitespacesAndNewlines)
  }

  func writeOfflinePDFPreparationStamp(instanceId: String, bookId: String, stamp: String) async {
    guard await isBookDownloaded(bookId: bookId) else { return }
    let file = bookDirectory(instanceId: instanceId, bookId: bookId).appendingPathComponent(
      Self.pdfPreparationStampFileName
    )
    guard let data = stamp.data(using: .utf8) else { return }
    do {
      try data.write(to: file)
      Self.excludeFromBackupIfNeeded(at: file)
    } catch {
      logger.error("❌ Failed to write PDF preparation stamp for book \(bookId): \(error)")
    }
  }

  func getOfflineEpubURL(instanceId: String, bookId: String) async -> URL? {
    guard await isBookDownloaded(bookId: bookId) else { return nil }
    let file = bookDirectory(instanceId: instanceId, bookId: bookId).appendingPathComponent(
      Self.epubFileName
    )
    return FileManager.default.fileExists(atPath: file.path) ? file : nil
  }

  func getOfflinePDFURL(instanceId: String, bookId: String) async -> URL? {
    guard await isBookDownloaded(bookId: bookId) else { return nil }
    let file = bookDirectory(instanceId: instanceId, bookId: bookId).appendingPathComponent(
      Self.pdfFileName
    )
    return FileManager.default.fileExists(atPath: file.path) ? file : nil
  }

  // MARK: - Resource Fetchers (Offline-Aware)

  func getBookPages(bookId: String) async throws -> [BookPage] {
    if let pages = try? await DatabaseOperator.database().fetchPages(id: bookId) {
      return pages
    }
    throw APIError.offline
  }

  func getBookTOC(bookId: String) async throws -> [ReaderTOCEntry] {
    if let toc = try? await DatabaseOperator.database().fetchTOC(id: bookId) {
      return toc
    }
    throw APIError.offline
  }

  func updateLocalProgress(bookId: String, page: Int, completed: Bool) async {
    try? await DatabaseOperator.database().updateReadingProgress(
      bookId: bookId, page: page, completed: completed)
    try? await DatabaseOperator.database().commit()
  }

  private nonisolated static func calculateDirectorySize(_ url: URL) throws -> Int64 {
    guard
      let enumerator = FileManager.default.enumerator(
        at: url,
        includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey],
        options: [.skipsHiddenFiles]
      )
    else {
      return 0
    }

    var total: Int64 = 0
    for case let fileURL as URL in enumerator {
      let attrs = try fileURL.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey])
      // Only count files, not directories
      if attrs.isDirectory == false {
        total += Int64(attrs.fileSize ?? 0)
      }
    }
    return total
  }

  private nonisolated static func directoryContainsFiles(_ url: URL) -> Bool {
    guard
      let enumerator = FileManager.default.enumerator(
        at: url,
        includingPropertiesForKeys: [.isDirectoryKey],
        options: [.skipsHiddenFiles]
      )
    else {
      return false
    }

    for case let fileURL as URL in enumerator {
      let attrs = try? fileURL.resourceValues(forKeys: [.isDirectoryKey])
      if attrs?.isDirectory == false {
        return true
      }
    }

    return false
  }

  // MARK: - Private Helpers

  private func refreshQueueStatus(instanceId: String) async {
    let summary =
      (try? await DatabaseOperator.database().fetchDownloadQueueSummary(instanceId: instanceId))
      ?? .empty
    await MainActor.run {
      DownloadProgressTracker.shared.updateQueueStatus(
        pending: summary.pendingCount,
        failed: summary.failedCount
      )
    }
  }

  private func removeActiveTask(_ bookId: String) {
    activeTasks[bookId]?.cancel()
    activeTasks[bookId] = nil
    let isQueueEmpty = activeTasks.isEmpty
    logger.info("🧹 Cleared active task for book: \(bookId)")
    Task { @MainActor in
      DownloadProgressTracker.shared.clearProgress(bookId: bookId)
      if isQueueEmpty {
        DownloadProgressTracker.shared.finishDownload()
      }
    }
  }

  #if os(iOS)
    private func updateForegroundLiveActivityProgress(bookId: String, progress: Double) async {
      guard let entry = foregroundDownloadInfoByBookId[bookId] else { return }
      let pendingBooks =
        (try? await DatabaseOperator.database().fetchPendingBooks(instanceId: entry.instanceId))
        ?? []
      let failedCount =
        (try? await DatabaseOperator.database().fetchFailedBooksCount(
          instanceId: entry.instanceId
        )) ?? 0
      await LiveActivityManager.shared.updateActivity(
        seriesTitle: entry.info.seriesTitle,
        bookInfo: entry.info.bookInfo,
        progress: progress,
        pendingCount: pendingBooks.count,
        failedCount: failedCount
      )
    }

    private func finishForegroundLiveActivity(bookId: String, instanceId: String) async {
      foregroundDownloadInfoByBookId.removeValue(forKey: bookId)

      let pendingBooks =
        (try? await DatabaseOperator.database().fetchPendingBooks(instanceId: instanceId)) ?? []
      let failedCount =
        (try? await DatabaseOperator.database().fetchFailedBooksCount(instanceId: instanceId))
        ?? 0

      if pendingBooks.isEmpty {
        if failedCount > 0 {
          await LiveActivityManager.shared.updateActivity(
            seriesTitle: String(localized: "Offline"),
            bookInfo: String(localized: "Download finished with failures"),
            progress: 1.0,
            pendingCount: 0,
            failedCount: failedCount
          )
        } else {
          await LiveActivityManager.shared.endActivity()
        }
        return
      }

      let candidate = foregroundDownloadInfoByBookId.values.first?.info
      let seriesTitle: String?
      let bookInfo: String
      if let candidate {
        seriesTitle = candidate.seriesTitle
        bookInfo = candidate.bookInfo
      } else {
        seriesTitle = String(localized: "Offline")
        bookInfo = String(localized: "Downloading")
      }
      await LiveActivityManager.shared.updateActivity(
        seriesTitle: seriesTitle,
        bookInfo: bookInfo,
        progress: 1.0,
        pendingCount: pendingBooks.count,
        failedCount: failedCount
      )
    }
  #endif

  private nonisolated func isNetworkRelatedError(_ error: Error) -> Bool {
    if let apiError = error as? APIError {
      if case .networkError = apiError { return true }
      if case .offline = apiError { return true }
    }
    if let nsError = error as NSError?, nsError.domain == NSURLErrorDomain {
      switch nsError.code {
      case NSURLErrorNotConnectedToInternet,
        NSURLErrorTimedOut,
        NSURLErrorCannotFindHost,
        NSURLErrorCannotConnectToHost,
        NSURLErrorNetworkConnectionLost,
        NSURLErrorResourceUnavailable:
        return true
      default:
        return false
      }
    }
    return false
  }

  private func shouldKeepPendingAfterNetworkFailure(_ error: Error) async -> Bool {
    guard isNetworkRelatedError(error) else { return false }
    if AppConfig.isOffline {
      return true
    }

    #if os(iOS)
      return await MainActor.run {
        UIApplication.shared.applicationState == .background
      }
    #else
      return false
    #endif
  }

  // MARK: - Background Download Handlers (iOS only)

  #if os(iOS)
    /// Track background download context per book
    private var backgroundDownloadInfo:
      [String: (
        instanceId: String, seriesTitle: String?, bookInfo: String, kind: DownloadContentKind
      )] = [:]
    private var backgroundDownloadTotalTasks: [String: Int] = [:]
    private var backgroundDownloadCompletedTasks: [String: Int] = [:]
    private var backgroundDownloadFinalizingBooks: Set<String> = []
    private func handleBackgroundDownloadComplete(
      bookId: String, pageNumber: Int?, fileURL: URL
    ) async {
      let backgroundTaskId = await startBackgroundTask()
      defer {
        Task {
          await endBackgroundTask(backgroundTaskId)
        }
      }
      _ = pageNumber
      _ = fileURL

      guard let info = backgroundDownloadInfo[bookId],
        let totalTasks = backgroundDownloadTotalTasks[bookId],
        totalTasks > 0
      else {
        if (try? await DatabaseOperator.database().getDownloadStatus(bookId: bookId))
          == .downloaded
        {
          return
        }
        logger.debug("⏭️ Ignore completion callback without active context for book: \(bookId)")
        return
      }

      let completedTasks = min((backgroundDownloadCompletedTasks[bookId] ?? 0) + 1, totalTasks)
      backgroundDownloadCompletedTasks[bookId] = completedTasks
      let progress = Double(completedTasks) / Double(totalTasks)
      let pendingBooks =
        (try? await DatabaseOperator.database().fetchPendingBooks(
          instanceId: info.instanceId
        )) ?? []
      let failedCount =
        (try? await DatabaseOperator.database().fetchFailedBooksCount(
          instanceId: info.instanceId
        )) ?? 0

      await MainActor.run {
        DownloadProgressTracker.shared.updateProgress(bookId: bookId, value: progress)
      }

      await LiveActivityManager.shared.updateActivity(
        seriesTitle: info.seriesTitle,
        bookInfo: info.bookInfo,
        progress: progress,
        pendingCount: pendingBooks.count,
        failedCount: failedCount
      )

      if completedTasks >= totalTasks {
        logger.debug(
          "✅ Final per-file background callback received for book \(bookId); waiting for all-complete callback"
        )
      }
    }

    private func handleBackgroundDownloadFailed(
      bookId: String, pageNumber: Int?, error: Error
    ) async {
      let backgroundTaskId = await startBackgroundTask()
      defer {
        Task {
          await endBackgroundTask(backgroundTaskId)
        }
      }
      _ = pageNumber

      guard let info = backgroundDownloadInfo[bookId] else {
        if (try? await DatabaseOperator.database().getDownloadStatus(bookId: bookId))
          == .downloaded
        {
          return
        }
        logger.warning(
          "⚠️ Missing background download context for failed task: \(bookId), recover queue from persisted state"
        )
        clearBackgroundDownloadContext(bookId: bookId)
        removeActiveTask(bookId)
        let instanceId = AppConfig.current.instanceId
        await refreshQueueStatus(instanceId: instanceId)
        await syncDownloadQueue(instanceId: instanceId)
        return
      }

      // Check if this is a network error while we're now offline
      let isNetworkError = isNetworkRelatedError(error)
      if isNetworkError && AppConfig.isOffline {
        // Network error caused offline mode switch - keep as pending for retry
        logger.info("⚠️ Background download paused due to network error: \(bookId)")
        return
      }

      // Mark book as failed
      logger.error("❌ Background download failed for \(bookId): \(error)")
      try? await DatabaseOperator.database().updateBookDownloadStatus(
        bookId: bookId,
        instanceId: info.instanceId,
        status: .failed(error: error.localizedDescription)
      )
      try? await DatabaseOperator.database().commit()
      await refreshQueueStatus(instanceId: info.instanceId)

      // Cancel remaining downloads for this book
      await BackgroundDownloadManager.shared.cancelDownloads(forBookId: bookId)
      clearBackgroundDownloadContext(bookId: bookId)
      removeActiveTask(bookId)

      // Update Live Activity or end if no more pending
      let pendingBooks =
        (try? await DatabaseOperator.database().fetchPendingBooks(
          instanceId: info.instanceId
        )) ?? []
      let failedCount =
        (try? await DatabaseOperator.database().fetchFailedBooksCount(
          instanceId: info.instanceId
        )) ?? 0

      if pendingBooks.isEmpty {
        if failedCount > 0 {
          // Keep showing if there are failures, update info to show summary
          await LiveActivityManager.shared.updateActivity(
            seriesTitle: String(localized: "Offline"),
            bookInfo: String(localized: "Download finished with failures"),
            progress: 1.0,
            pendingCount: 0,
            failedCount: failedCount
          )
        } else {
          await LiveActivityManager.shared.endActivity()
        }
      } else {
        await LiveActivityManager.shared.updateActivity(
          seriesTitle: info.seriesTitle,
          bookInfo: info.bookInfo,
          progress: 1.0,
          pendingCount: pendingBooks.count,
          failedCount: failedCount
        )
      }

      // Trigger next download
      await syncDownloadQueue(instanceId: info.instanceId)
    }

    private func handleAllBackgroundDownloadsComplete(bookId: String) async {
      let backgroundTaskId = await startBackgroundTask()
      defer {
        Task {
          await endBackgroundTask(backgroundTaskId)
        }
      }

      guard let info = backgroundDownloadInfo[bookId] else {
        if (try? await DatabaseOperator.database().getDownloadStatus(bookId: bookId))
          == .downloaded
        {
          return
        }
        logger.debug("⏭️ Ignore all-complete callback without active context for book: \(bookId)")
        return
      }

      let totalTasks = backgroundDownloadTotalTasks[bookId] ?? 0
      let completedTasks = backgroundDownloadCompletedTasks[bookId] ?? 0
      if totalTasks > 0, completedTasks < totalTasks {
        logger.debug(
          "⏳ Defer all-complete callback: waiting per-file callbacks for book \(bookId), \(completedTasks)/\(totalTasks)"
        )
        return
      }

      if backgroundDownloadFinalizingBooks.contains(bookId) {
        logger.debug(
          "⏭️ Ignore duplicate all-complete callback while finalizing book \(bookId), completed=\(completedTasks)/\(totalTasks)"
        )
        return
      }

      backgroundDownloadFinalizingBooks.insert(bookId)
      logger.debug(
        "🔒 Claimed background finalize for book \(bookId), completed=\(completedTasks)/\(totalTasks)"
      )
      await finalizeBackgroundBookDownload(bookId: bookId, info: info)
    }

    private func finalizeBackgroundBookDownload(
      bookId: String,
      info: (instanceId: String, seriesTitle: String?, bookInfo: String, kind: DownloadContentKind)
    ) async {
      defer {
        backgroundDownloadFinalizingBooks.remove(bookId)
      }
      logger.info("✅ Background downloads finished for book: \(bookId)")
      let bookDir = bookDirectory(instanceId: info.instanceId, bookId: bookId)

      // Extract EPUB file if present (single-file download approach)
      let epubFile = bookDir.appendingPathComponent(Self.epubFileName)
      if FileManager.default.fileExists(atPath: epubFile.path) {
        let recoveryMessage = "Offline EPUB download is incomplete. Please retry downloading this book."

        func failExtraction(_ message: String) async {
          logger.error("❌ \(message): \(bookId)")
          try? FileManager.default.removeItem(at: bookDir)
          try? await DatabaseOperator.database().updateBookDownloadStatus(
            bookId: bookId, instanceId: info.instanceId, status: .failed(error: message))
          try? await DatabaseOperator.database().commit()
          clearBackgroundDownloadContext(bookId: bookId)
          removeActiveTask(bookId)
          await refreshQueueStatus(instanceId: info.instanceId)
          await syncDownloadQueue(instanceId: info.instanceId)
        }

        guard
          let manifest = try? await DatabaseOperator.database().fetchWebPubManifest(
            bookId: bookId, instanceId: info.instanceId)
        else {
          logger.error(
            "❌ Missing WebPub manifest during background EPUB finalization for book \(bookId), bookDir=\(bookDir.path)"
          )
          await failExtraction(recoveryMessage)
          return
        }
        do {
          try extractEpubToWebPub(
            epubFile: epubFile, bookId: bookId, manifest: manifest, bookDir: bookDir)
          try? FileManager.default.removeItem(at: epubFile)
        } catch {
          logger.error(
            "❌ Background EPUB extraction failed for book \(bookId), file=\(epubFile.lastPathComponent), bookDir=\(bookDir.path), error=\(error.localizedDescription)"
          )
          await failExtraction(recoveryMessage)
          return
        }
      } else if !Self.directoryContainsFiles(webPubRootURL(bookDir: bookDir)) {
        switch info.kind {
        case .epubWebPub:
          logger.warning(
            "⚠️ EPUB archive and extracted resources are both missing during background finalization for book \(bookId), bookDir=\(bookDir.path)"
          )
          try? await DatabaseOperator.database().updateBookDownloadStatus(
            bookId: bookId,
            instanceId: info.instanceId,
            status: .failed(error: "Offline EPUB download is incomplete. Please retry downloading this book.")
          )
          try? await DatabaseOperator.database().commit()
          clearBackgroundDownloadContext(bookId: bookId)
          removeActiveTask(bookId)
          await refreshQueueStatus(instanceId: info.instanceId)
          await syncDownloadQueue(instanceId: info.instanceId)
          return
        default:
          break
        }
      }

      await finalizeDownload(
        instanceId: info.instanceId,
        bookId: bookId,
        bookDir: bookDir
      )
      logger.info("✅ All background downloads complete for book: \(bookId)")

      clearBackgroundDownloadContext(bookId: bookId)

      let pendingBooks =
        (try? await DatabaseOperator.database().fetchPendingBooks(
          instanceId: info.instanceId
        )) ?? []
      if pendingBooks.isEmpty {
        let failedCount =
          (try? await DatabaseOperator.database().fetchFailedBooksCount(
            instanceId: info.instanceId
          )) ?? 0
        if failedCount > 0 {
          await LiveActivityManager.shared.updateActivity(
            seriesTitle: String(localized: "Offline"),
            bookInfo: String(localized: "Download finished with failures"),
            progress: 1.0,
            pendingCount: 0,
            failedCount: failedCount
          )
        } else {
          await LiveActivityManager.shared.endActivity()
        }
      }

      await syncDownloadQueue(instanceId: info.instanceId)
    }
  #endif

  // MARK: - Download Logic

  private func downloadEpub(bookId: String, to bookDir: URL) async throws {
    // Save pages metadata to DB
    let pages = try await BookService.shared.getBookPages(id: bookId)
    try? await DatabaseOperator.database().updateBookPages(bookId: bookId, pages: pages)
    try? await DatabaseOperator.database().commit()

    // Save TOC if it exists to DB
    if let manifest = try? await BookService.shared.getBookManifest(id: bookId) {
      let toc = await ReaderManifestService(bookId: bookId).parseTOC(manifest: manifest)
      try? await DatabaseOperator.database().updateBookTOC(bookId: bookId, toc: toc)
      try? await DatabaseOperator.database().commit()
    }

    let webPubManifest = try await BookService.shared.getBookWebPubManifest(bookId: bookId)
    try? await DatabaseOperator.database().updateBookWebPubManifest(bookId: bookId, manifest: webPubManifest)
    try? await DatabaseOperator.database().commit()

    // Download the original EPUB file and extract as ZIP
    try await downloadAndExtractEpub(bookId: bookId, manifest: webPubManifest, bookDir: bookDir)
  }

  private func downloadPdfFile(bookId: String, to bookDir: URL) async throws {
    let fileURL = bookDir.appendingPathComponent(Self.pdfFileName)
    let result = try await BookService.shared.downloadBookFile(bookId: bookId)
    try result.data.write(to: fileURL, options: [.atomic])
    Self.excludeFromBackupIfNeeded(at: fileURL)
    await MainActor.run {
      DownloadProgressTracker.shared.updateProgress(bookId: bookId, value: 1.0)
    }
    #if os(iOS)
      await updateForegroundLiveActivityProgress(bookId: bookId, progress: 1.0)
    #endif
  }

  private func downloadAndExtractEpub(
    bookId: String,
    manifest: WebPubPublication,
    bookDir: URL
  ) async throws {
    await MainActor.run {
      DownloadProgressTracker.shared.updateProgress(bookId: bookId, value: 0.0)
    }

    let result = try await BookService.shared.downloadBookFile(bookId: bookId)

    await MainActor.run {
      DownloadProgressTracker.shared.updateProgress(bookId: bookId, value: 0.5)
    }

    let epubFile = bookDir.appendingPathComponent(Self.epubFileName)
    try result.data.write(to: epubFile, options: [.atomic])
    Self.excludeFromBackupIfNeeded(at: epubFile)

    try Task.checkCancellation()
    try extractEpubToWebPub(epubFile: epubFile, bookId: bookId, manifest: manifest, bookDir: bookDir)

    // Clean up the EPUB file after extraction
    try? FileManager.default.removeItem(at: epubFile)

    await MainActor.run {
      DownloadProgressTracker.shared.updateProgress(bookId: bookId, value: 1.0)
    }
    #if os(iOS)
      await updateForegroundLiveActivityProgress(bookId: bookId, progress: 1.0)
    #endif
  }

  private func extractEpubToWebPub(
    epubFile: URL,
    bookId: String,
    manifest: WebPubPublication,
    bookDir: URL
  ) throws {
    let root = bookDir.appendingPathComponent("webpub", isDirectory: true)
    Self.ensureDirectoryExists(at: root)
    Self.excludeFromBackupIfNeeded(at: root)

    let resourceLinks = collectWebPubResourceLinks(from: manifest)
    let hrefs = Array(Set(resourceLinks))

    guard !hrefs.isEmpty else { return }

    let archive = try Archive(url: epubFile, accessMode: .read)

    // Komga already normalizes EPUB hrefs to publication resource keys.
    var archivePathToDestination: [String: URL] = [:]
    for href in hrefs {
      guard let archivePath = Self.manifestResourcePath(from: href),
        let normalizedArchivePath = Self.normalizeArchivePath(archivePath)
      else { continue }
      let destination = Self.webPubResourceURL(root: root, href: href)
      archivePathToDestination[normalizedArchivePath] = destination
    }

    for entry in archive where entry.type == .file {
      guard
        let normalizedEntryPath = Self.normalizeArchivePath(entry.path),
        let destination = archivePathToDestination[normalizedEntryPath]
      else { continue }

      let directory = destination.deletingLastPathComponent()
      Self.ensureDirectoryExists(at: directory)
      Self.excludeFromBackupIfNeeded(at: directory)

      if FileManager.default.fileExists(atPath: destination.path) {
        try FileManager.default.removeItem(at: destination)
      }

      _ = try archive.extract(entry, to: destination)
      Self.excludeFromBackupIfNeeded(at: destination)
    }
  }

  private static func manifestResourcePath(from href: String) -> String? {
    let trimmed = href.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }

    var path = URLComponents(string: trimmed)?.path ?? trimmed
    if let range = path.range(of: "/resource/", options: .backwards) {
      path = String(path[range.upperBound...])
    }

    let withoutFragment = path.split(separator: "#", maxSplits: 1).first.map(String.init) ?? path
    let withoutQuery =
      withoutFragment.split(separator: "?", maxSplits: 1).first.map(String.init) ?? withoutFragment
    let decodedPath = withoutQuery.removingPercentEncoding ?? withoutQuery
    return decodedPath.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
  }

  private static func normalizeArchivePath(_ path: String) -> String? {
    let components = path.split(separator: "/").map(String.init)
    guard !components.isEmpty else { return nil }

    var normalized: [String] = []
    for component in components {
      switch component {
      case "", ".":
        continue
      case "..":
        guard !normalized.isEmpty else { return nil }
        normalized.removeLast()
      default:
        normalized.append(component)
      }
    }

    guard !normalized.isEmpty else { return nil }
    return normalized.joined(separator: "/")
  }

  private func collectWebPubResourceLinks(from manifest: WebPubPublication) -> [String] {
    let collections = [
      manifest.readingOrder,
      manifest.resources,
      manifest.images,
      manifest.links,
      manifest.pageList,
      manifest.toc,
      manifest.landmarks,
    ]

    return collections.flatMap { links in
      links.compactMap { link in
        guard !link.href.isEmpty else { return nil }
        if link.templated == true { return nil }
        if link.href.hasPrefix("#") || link.href.hasPrefix("data:") { return nil }
        return link.href
      }
    }
  }

  private func downloadPages(bookId: String, to bookDir: URL) async throws {
    let pages = try await BookService.shared.getBookPages(id: bookId)

    // Save pages metadata to DB
    try? await DatabaseOperator.database().updateBookPages(bookId: bookId, pages: pages)
    try? await DatabaseOperator.database().commit()

    // Save TOC to DB
    if let manifest = try? await BookService.shared.getBookManifest(id: bookId) {
      let toc = await ReaderManifestService(bookId: bookId).parseTOC(manifest: manifest)
      try? await DatabaseOperator.database().updateBookTOC(bookId: bookId, toc: toc)
      try? await DatabaseOperator.database().commit()
    }

    var pagesToDownload: [BookPage] = []

    for page in pages {
      let ext = page.detectedUTType?.preferredFilenameExtension ?? "jpg"
      let destination = bookDir.appendingPathComponent("page-\(page.number).\(ext)")

      if FileManager.default.fileExists(atPath: destination.path) {
        continue
      }

      if await copyCachedPageIfAvailable(
        bookId: bookId,
        page: page,
        destination: destination
      ) {
        continue
      }

      pagesToDownload.append(page)
    }

    let total = Double(pages.count)
    var completedCount = pages.count - pagesToDownload.count
    if total > 0, completedCount > 0 {
      let progress = Double(completedCount) / total
      await MainActor.run {
        DownloadProgressTracker.shared.updateProgress(bookId: bookId, value: progress)
      }
    }

    if pagesToDownload.isEmpty {
      await MainActor.run {
        DownloadProgressTracker.shared.updateProgress(bookId: bookId, value: 1.0)
      }
      return
    }

    try await withThrowingTaskGroup(of: Void.self) { group in
      let maxConcurrent = 4
      var active = 0
      var iterator = pagesToDownload.makeIterator()

      func submitNext() {
        if let page = iterator.next() {
          let ext = page.detectedUTType?.preferredFilenameExtension ?? "jpg"
          group.addTask {
            try Task.checkCancellation()
            let fileName = "page-\(page.number).\(ext)"
            let dest = bookDir.appendingPathComponent(fileName)

            if !FileManager.default.fileExists(atPath: dest.path) {
              let (data, _) = try await BookService.shared.getBookPage(
                bookId: bookId, page: page.number)
              try data.write(to: dest)
              Self.excludeFromBackupIfNeeded(at: dest)
            }
          }
          active += 1
        }
      }

      // Initial fill
      for _ in 0..<maxConcurrent {
        submitNext()
      }

      while active > 0 {
        try await group.next()
        active -= 1
        completedCount += 1

        let progress = Double(completedCount) / total

        // Update in-memory progress for UI
        await MainActor.run {
          DownloadProgressTracker.shared.updateProgress(bookId: bookId, value: progress)
        }

        submitNext()
      }
    }
  }

  private func copyCachedPageIfAvailable(
    bookId: String,
    page: BookPage,
    destination: URL
  ) async -> Bool {
    if FileManager.default.fileExists(atPath: destination.path) {
      return true
    }

    guard await pageImageCache.hasImage(bookId: bookId, page: page) else {
      return false
    }

    let cachedURL = pageImageCache.imageFileURL(bookId: bookId, page: page)
    do {
      try FileManager.default.copyItem(at: cachedURL, to: destination)
      Self.excludeFromBackupIfNeeded(at: destination)
      return true
    } catch {
      logger.error("❌ Failed to copy cached page for book \(bookId) page \(page.number): \(error)")
      return false
    }
  }

  private func clearCachesAfterDownload(bookId: String) async {
    await ImageCache.clearDiskCache(forBookId: bookId)
  }

  private func finalizeDownload(
    instanceId: String,
    bookId: String,
    bookDir: URL
  ) async {
    try? await DatabaseOperator.database().updateBookDownloadStatus(
      bookId: bookId,
      instanceId: instanceId,
      status: .downloaded,
      downloadAt: .now
    )
    try? await DatabaseOperator.database().commit()
    await refreshQueueStatus(instanceId: instanceId)
    await clearCachesAfterDownload(bookId: bookId)
    completedDownloadsSinceLastNotification += 1
    removeActiveTask(bookId)
    scheduleDownloadedSizeUpdate(instanceId: instanceId, bookId: bookId, bookDir: bookDir)

    #if os(iOS) || os(macOS)
      let compositeId = CompositeID.generate(instanceId: instanceId, id: bookId)
      if let book = try? await DatabaseOperator.database().fetchBook(id: compositeId) {
        SpotlightIndexService.indexBook(book, instanceId: instanceId)
      }
    #endif
  }

  private func scheduleDownloadedSizeUpdate(
    instanceId: String,
    bookId: String,
    bookDir: URL
  ) {
    Task.detached {
      guard let size = try? Self.calculateDirectorySize(bookDir) else { return }
      try? await DatabaseOperator.database().updateBookDownloadStatus(
        bookId: bookId,
        instanceId: instanceId,
        status: .downloaded,
        downloadedSize: size
      )
      try? await DatabaseOperator.database().commit()
    }
  }

  // MARK: - File System Helpers

  private static func ensureDirectoryExists(at url: URL) {
    var isDirectory: ObjCBool = false
    if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
      isDirectory.boolValue
    {
      return
    }
    try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
  }

  private static func excludeFromBackupIfNeeded(at url: URL) {
    var values = URLResourceValues()
    values.isExcludedFromBackup = true
    var target = url
    try? target.setResourceValues(values)
  }

  private static func migrateLegacyDirectoryIfNeeded(to destination: URL) {
    let legacy = legacyBaseDirectory()
    var legacyIsDirectory: ObjCBool = false
    guard FileManager.default.fileExists(atPath: legacy.path, isDirectory: &legacyIsDirectory),
      legacyIsDirectory.boolValue
    else {
      return
    }

    var destinationIsDirectory: ObjCBool = false
    let destinationExists = FileManager.default.fileExists(
      atPath: destination.path, isDirectory: &destinationIsDirectory)

    if !destinationExists {
      if (try? FileManager.default.moveItem(at: legacy, to: destination)) != nil {
        return
      }
    } else if destinationIsDirectory.boolValue, isDirectoryEmpty(at: destination) {
      do {
        try FileManager.default.removeItem(at: destination)
        try FileManager.default.moveItem(at: legacy, to: destination)
        return
      } catch {
        // Fall back to merge.
      }
    }

    mergeDirectoryContents(from: legacy, to: destination)
    if isDirectoryEmpty(at: legacy) {
      try? FileManager.default.removeItem(at: legacy)
    }
  }

  private static func legacyBaseDirectory() -> URL {
    let documentsDir =
      FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
      ?? FileManager.default.temporaryDirectory
    return documentsDir.appendingPathComponent(directoryName, isDirectory: true)
  }

  private static func mergeDirectoryContents(from source: URL, to destination: URL) {
    guard
      let items = try? FileManager.default.contentsOfDirectory(
        at: source,
        includingPropertiesForKeys: [.isDirectoryKey],
        options: [.skipsHiddenFiles]
      )
    else {
      return
    }

    for item in items {
      let destinationURL = destination.appendingPathComponent(item.lastPathComponent)
      var sourceIsDirectory: ObjCBool = false
      FileManager.default.fileExists(atPath: item.path, isDirectory: &sourceIsDirectory)

      var destinationIsDirectory: ObjCBool = false
      let destinationExists = FileManager.default.fileExists(
        atPath: destinationURL.path, isDirectory: &destinationIsDirectory)

      if !destinationExists {
        try? FileManager.default.moveItem(at: item, to: destinationURL)
        excludeFromBackupIfNeeded(at: destinationURL)
        continue
      }

      if sourceIsDirectory.boolValue && destinationIsDirectory.boolValue {
        mergeDirectoryContents(from: item, to: destinationURL)
        if isDirectoryEmpty(at: item) {
          try? FileManager.default.removeItem(at: item)
        }
        continue
      }

      try? FileManager.default.removeItem(at: item)
    }
  }

  private static func isDirectoryEmpty(at url: URL) -> Bool {
    guard let contents = try? FileManager.default.contentsOfDirectory(atPath: url.path) else {
      return false
    }
    return contents.isEmpty
  }
}

// MARK: - Helper Extension

extension Book {
  var downloadInfo: DownloadInfo {
    let kind: DownloadContentKind
    if media.mediaProfileValue == .pdf {
      kind = .pdf
    } else if media.mediaProfileValue == .epub {
      kind = (media.epubDivinaCompatible ?? false) ? .epubDivina : .epubWebPub
    } else {
      kind = .pages
    }

    return DownloadInfo(
      bookId: id,
      seriesTitle: oneshot ? nil : seriesTitle,
      bookInfo: oneshot ? "\(metadata.title)" : "#\(metadata.number) - \(metadata.title)",
      kind: kind
    )
  }
}
