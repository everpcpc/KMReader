//
//  OfflineManager.swift
//  KMReader
//
//  Created by Komga iOS Client
//

import Combine
import Foundation
import OSLog
import UniformTypeIdentifiers

#if os(iOS)
  import UIKit
#endif

#if os(iOS)
  private typealias BackgroundTaskID = UIBackgroundTaskIdentifier
#else
  private typealias BackgroundTaskID = Int
#endif

/// Simple Sendable struct for download info.
struct DownloadInfo: Sendable {
  let bookId: String
  let seriesTitle: String
  let bookInfo: String
  let isEpub: Bool
  let epubDivinaCompatible: Bool
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

  // MARK: - Paths

  /// Base directory for all offline books.
  private static func baseDirectory() -> URL {
    let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    return documentsDir.appendingPathComponent(directoryName, isDirectory: true)
  }

  /// Namespaced directory for a specific instance's offline books.
  private static func offlineDirectory(for instanceId: String) -> URL {
    let sanitized = instanceId.isEmpty ? "default" : instanceId
    let url = baseDirectory().appendingPathComponent(sanitized, isDirectory: true)
    var isDir: ObjCBool = false
    if !FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) || !isDir.boolValue {
      try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }
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
    if !FileManager.default.fileExists(atPath: url.path) {
      try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }
    return url
  }

  // MARK: - Public API

  /// Get the download status of a book from SwiftData.
  func getDownloadStatus(bookId: String) async -> DownloadStatus {
    await DatabaseOperator.shared.getDownloadStatus(bookId: bookId)
  }

  /// Check if a book is downloaded.
  func isBookDownloaded(bookId: String) async -> Bool {
    if case .downloaded = await getDownloadStatus(bookId: bookId) {
      return true
    }
    return false
  }

  func toggleDownload(instanceId: String, info: DownloadInfo) async {
    let status = await getDownloadStatus(bookId: info.bookId)
    switch status {
    case .downloaded:
      await deleteBook(instanceId: instanceId, bookId: info.bookId)
    case .pending:
      await cancelDownload(bookId: info.bookId, instanceId: instanceId)
    case .notDownloaded, .failed:
      await DatabaseOperator.shared.updateBookDownloadStatus(
        bookId: info.bookId,
        instanceId: instanceId,
        status: .pending,
        downloadAt: .now
      )
      await DatabaseOperator.shared.commit()
      await syncDownloadQueue(instanceId: instanceId)
    }
  }

  func retryDownload(instanceId: String, bookId: String) async {
    await DatabaseOperator.shared.updateBookDownloadStatus(
      bookId: bookId,
      instanceId: instanceId,
      status: .pending,
      downloadAt: .now
    )
    await DatabaseOperator.shared.commit()
    await syncDownloadQueue(instanceId: instanceId)
  }

  func deleteBook(
    instanceId: String, bookId: String, commit: Bool = true, syncSeriesStatus: Bool = true
  ) async {
    await cancelDownload(
      bookId: bookId, instanceId: instanceId, commit: false, syncSeriesStatus: syncSeriesStatus)
    let dir = bookDirectory(instanceId: instanceId, bookId: bookId)

    // Update SwiftData
    await DatabaseOperator.shared.updateBookDownloadStatus(
      bookId: bookId, instanceId: instanceId, status: .notDownloaded,
      syncSeriesStatus: syncSeriesStatus
    )
    if commit {
      await DatabaseOperator.shared.commit()
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
  }

  /// Delete a book manually, setting series policy to manual first to prevent automatic re-download.
  func deleteBookManually(seriesId: String, instanceId: String, bookId: String) async {
    await DatabaseOperator.shared.updateSeriesOfflinePolicy(
      seriesId: seriesId,
      instanceId: instanceId,
      policy: .manual,
      syncSeriesStatus: false
    )
    await deleteBook(instanceId: instanceId, bookId: bookId)
  }

  /// Delete multiple books manually, setting series policy to manual first to prevent automatic re-download.
  func deleteBooksManually(seriesId: String, instanceId: String, bookIds: [String]) async {
    await DatabaseOperator.shared.updateSeriesOfflinePolicy(
      seriesId: seriesId,
      instanceId: instanceId,
      policy: .manual,
      syncSeriesStatus: false
    )
    for bookId in bookIds {
      await deleteBook(
        instanceId: instanceId, bookId: bookId, commit: false, syncSeriesStatus: false)
    }
    await DatabaseOperator.shared.syncSeriesDownloadStatus(
      seriesId: seriesId, instanceId: instanceId)
    await DatabaseOperator.shared.commit()
  }

  /// Delete all downloaded books for the current instance.
  func deleteAllDownloadedBooks() async {
    let instanceId = AppConfig.currentInstanceId
    let books = await DatabaseOperator.shared.fetchDownloadedBooks(instanceId: instanceId)

    // Group by series to update policies
    let seriesIds = Set(books.map { $0.seriesId })
    for seriesId in seriesIds {
      await DatabaseOperator.shared.updateSeriesOfflinePolicy(
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
      await DatabaseOperator.shared.syncSeriesDownloadStatus(
        seriesId: seriesId, instanceId: instanceId)
    }
    await DatabaseOperator.shared.commit()
  }

  /// Delete all read (completed) downloaded books for the current instance.
  func deleteReadBooks() async {
    let instanceId = AppConfig.currentInstanceId
    let books = await DatabaseOperator.shared.fetchDownloadedBooks(instanceId: instanceId)
    let readBooks = books.filter { $0.readProgress?.completed == true }

    // Group by series to update policies
    let seriesIds = Set(readBooks.map { $0.seriesId })
    for seriesId in seriesIds {
      await DatabaseOperator.shared.updateSeriesOfflinePolicy(
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
      await DatabaseOperator.shared.syncSeriesDownloadStatus(
        seriesId: seriesId, instanceId: instanceId)
    }
    await DatabaseOperator.shared.commit()
  }

  func cancelDownload(
    bookId: String, instanceId: String? = nil, commit: Bool = true, syncSeriesStatus: Bool = true
  ) async {
    activeTasks[bookId]?.cancel()
    activeTasks[bookId] = nil
    let resolvedInstanceId = instanceId ?? AppConfig.currentInstanceId
    await DatabaseOperator.shared.updateBookDownloadStatus(
      bookId: bookId, instanceId: resolvedInstanceId, status: .notDownloaded,
      syncSeriesStatus: syncSeriesStatus
    )
    if commit {
      await DatabaseOperator.shared.commit()
    }
  }

  /// Cancel all active downloads (used during cleanup).
  func cancelAllDownloads() async {
    let instanceId = AppConfig.currentInstanceId
    for (bookId, task) in activeTasks {
      task.cancel()
      await DatabaseOperator.shared.updateBookDownloadStatus(
        bookId: bookId, instanceId: instanceId, status: .notDownloaded
      )
      await DatabaseOperator.shared.commit()
    }
    activeTasks.removeAll()
    #if os(iOS)
      await LiveActivityManager.shared.endActivity()
    #endif
  }

  func retryFailedDownloads(instanceId: String) async {
    await DatabaseOperator.shared.retryFailedBooks(instanceId: instanceId)
    await DatabaseOperator.shared.commit()
    await syncDownloadQueue(instanceId: instanceId)
  }

  func cancelFailedDownloads(instanceId: String) async {
    await DatabaseOperator.shared.cancelFailedBooks(instanceId: instanceId)
    await DatabaseOperator.shared.commit()
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

    let pending = await DatabaseOperator.shared.fetchPendingBooks(limit: 1)

    guard let nextBook = pending.first else { return }

    await startDownload(instanceId: instanceId, info: nextBook.downloadInfo)
  }

  private func startDownload(instanceId: String, info: DownloadInfo) async {
    guard activeTasks[info.bookId] == nil else { return }

    // Initialize progress (status stays as pending during download)
    await MainActor.run {
      DownloadProgressTracker.shared.updateProgress(bookId: info.bookId, value: 0.0)
    }

    let bookDir = bookDirectory(instanceId: instanceId, bookId: info.bookId)

    #if os(iOS)
      // Use background downloads on iOS
      await startBackgroundDownload(
        instanceId: instanceId, info: info, bookDir: bookDir)
    #else
      // Use in-process downloads on macOS/tvOS
      await startForegroundDownload(
        instanceId: instanceId, info: info, bookDir: bookDir)
    #endif
  }

  #if os(iOS)
    private func startBackgroundDownload(
      instanceId: String, info: DownloadInfo, bookDir: URL
    ) async {
      logger.info("⬇️ Starting background download for book: \(info.bookInfo) (\(info.bookId))")

      do {
        // Get pending count and failed count for Live Activity
        let pendingBooks = await DatabaseOperator.shared.fetchPendingBooks()
        let failedCount = await DatabaseOperator.shared.fetchFailedBooksCount(
          instanceId: instanceId)

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
        await DatabaseOperator.shared.updateBookPages(bookId: info.bookId, pages: pages)
        await DatabaseOperator.shared.commit()

        // Save TOC if available
        if let manifest = try? await BookService.shared.getBookManifest(id: info.bookId) {
          let toc = await ReaderManifestService(bookId: info.bookId).parseTOC(manifest: manifest)
          await DatabaseOperator.shared.updateBookTOC(bookId: info.bookId, toc: toc)
          await DatabaseOperator.shared.commit()
        }

        let isEpub = info.isEpub && !info.epubDivinaCompatible
        if isEpub {
          let destination = bookDir.appendingPathComponent("book.epub")
          if await copyCachedEpubIfAvailable(bookId: info.bookId, destination: destination) {
            logger.info("✅ Using cached EPUB for book: \(info.bookId)")
            let totalSize = (try? calculateDirectorySize(bookDir)) ?? 0
            await DatabaseOperator.shared.updateBookDownloadStatus(
              bookId: info.bookId,
              instanceId: instanceId,
              status: .downloaded,
              downloadedSize: totalSize
            )
            await DatabaseOperator.shared.commit()
            await clearCachesAfterDownload(bookId: info.bookId, isEpub: true)
            removeActiveTask(info.bookId)
            await syncDownloadQueue(instanceId: instanceId)
            return
          }
        }

        // Store download info for completion handling
        backgroundDownloadInfo[info.bookId] = (
          instanceId: instanceId,
          seriesTitle: info.seriesTitle,
          bookInfo: info.bookInfo,
          isEpub: isEpub,
          totalPages: pages.count
        )

        let serverURL = await MainActor.run { AppConfig.serverURL }

        if isEpub {
          // EPUB: single file download
          guard
            let downloadURL = URL(
              string: serverURL + "/api/v1/books/\(info.bookId)/file")
          else {
            throw APIError.invalidURL
          }
          let destPath = bookDir.appendingPathComponent("book.epub").path

          activeTasks[info.bookId] = Task {
            // Wait indefinitely until explicitly cancelled via removeActiveTask
            try? await Task.sleep(nanoseconds: UInt64.max)
          }

          await MainActor.run {
            BackgroundDownloadManager.shared.downloadEpub(
              bookId: info.bookId,
              instanceId: instanceId,
              url: downloadURL,
              destinationPath: destPath
            )
          }
        } else {
          // Pages: multiple downloads, skip already downloaded pages
          var pagesToDownload: [BookPage] = []

          for page in pages {
            let ext = page.detectedUTType?.preferredFilenameExtension ?? "jpg"
            let destination = bookDir.appendingPathComponent("page-\(page.number).\(ext)")

            // Skip if page already exists
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

          let completedCount = pages.count - pagesToDownload.count
          if pages.count > 0, completedCount > 0 {
            let progress = Double(completedCount) / Double(pages.count)
            await MainActor.run {
              DownloadProgressTracker.shared.updateProgress(bookId: info.bookId, value: progress)
            }
            await LiveActivityManager.shared.updateActivity(
              seriesTitle: info.seriesTitle,
              bookInfo: info.bookInfo,
              progress: progress,
              pendingCount: pendingBooks.count,
              failedCount: failedCount
            )
          }

          // If all pages already exist, mark as complete
          if pagesToDownload.isEmpty {
            logger.info("✅ All pages already downloaded for book: \(info.bookId)")
            let totalSize = (try? calculateDirectorySize(bookDir)) ?? 0
            await DatabaseOperator.shared.updateBookDownloadStatus(
              bookId: info.bookId,
              instanceId: instanceId,
              status: .downloaded,
              downloadedSize: totalSize
            )
            await DatabaseOperator.shared.commit()
            await clearCachesAfterDownload(bookId: info.bookId, isEpub: false)
            backgroundDownloadInfo.removeValue(forKey: info.bookId)
            removeActiveTask(info.bookId)
            await syncDownloadQueue(instanceId: instanceId)
            return
          }

          pendingBackgroundPages[info.bookId] = Set(pagesToDownload.map { $0.number })

          activeTasks[info.bookId] = Task {
            // Wait indefinitely until explicitly cancelled via removeActiveTask
            try? await Task.sleep(nanoseconds: UInt64.max)
          }

          for page in pagesToDownload {
            guard
              let downloadURL = URL(
                string: serverURL + "/api/v1/books/\(info.bookId)/pages/\(page.number)")
            else { continue }

            let ext = page.detectedUTType?.preferredFilenameExtension ?? "jpg"
            let destPath = bookDir.appendingPathComponent("page-\(page.number).\(ext)").path

            await MainActor.run {
              BackgroundDownloadManager.shared.downloadPage(
                bookId: info.bookId,
                instanceId: instanceId,
                pageNumber: page.number,
                url: downloadURL,
                destinationPath: destPath
              )
            }
          }
        }
      } catch {
        logger.error("❌ Failed to start background download for \(info.bookId): \(error)")
        await DatabaseOperator.shared.updateBookDownloadStatus(
          bookId: info.bookId,
          instanceId: instanceId,
          status: .failed(error: error.localizedDescription)
        )
        await DatabaseOperator.shared.commit()
        await syncDownloadQueue(instanceId: instanceId)
      }
    }
  #endif

  private func startForegroundDownload(
    instanceId: String, info: DownloadInfo, bookDir: URL
  ) async {
    activeTasks[info.bookId] = Task { [weak self, logger] in
      guard let self else { return }
      do {
        logger.info("⬇️ Starting download for book: \(info.bookInfo) (\(info.bookId))")

        let isEpub = info.isEpub && !info.epubDivinaCompatible
        if isEpub {
          try await downloadEpub(bookId: info.bookId, to: bookDir)
        } else {
          try await downloadPages(bookId: info.bookId, to: bookDir)
        }

        // Mark complete in SwiftData
        let totalSize = try await self.calculateDirectorySize(bookDir)
        await DatabaseOperator.shared.updateBookDownloadStatus(
          bookId: info.bookId, instanceId: instanceId, status: .downloaded,
          downloadedSize: totalSize
        )
        await DatabaseOperator.shared.commit()
        await clearCachesAfterDownload(bookId: info.bookId, isEpub: isEpub)
        await removeActiveTask(info.bookId)
        logger.info("✅ Download complete for book: \(info.bookId)")

        // Trigger next download
        await syncDownloadQueue(instanceId: instanceId)

      } catch {
        // Cleanup on failure
        try? FileManager.default.removeItem(at: bookDir)

        if Task.isCancelled {
          logger.info("⛔ Download cancelled for book: \(info.bookId)")
        } else {
          // Check if this is a network error while we're now offline
          let isNetworkError = self.isNetworkRelatedError(error)
          if isNetworkError && AppConfig.isOffline {
            // Network error caused offline mode switch - don't mark as failed.
            // Keep status as pending so it retries when online.
            logger.info("⚠️ Download paused due to network error: \(info.bookId)")
          } else {
            logger.error("❌ Download failed for book \(info.bookId): \(error)")
            await DatabaseOperator.shared.updateBookDownloadStatus(
              bookId: info.bookId,
              instanceId: instanceId,
              status: .failed(error: error.localizedDescription)
            )
            await DatabaseOperator.shared.commit()
          }
        }
        await removeActiveTask(info.bookId)

        // Trigger next download even on failure or cancellation
        await syncDownloadQueue(instanceId: instanceId)
      }
    }
  }

  func cancelDownload(bookId: String) async {
    activeTasks[bookId]?.cancel()
    activeTasks[bookId] = nil
    let instanceId = AppConfig.currentInstanceId
    await DatabaseOperator.shared.updateBookDownloadStatus(
      bookId: bookId, instanceId: instanceId, status: .notDownloaded
    )
    await DatabaseOperator.shared.commit()
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

  func getOfflineEpubURL(instanceId: String, bookId: String) async -> URL? {
    guard await isBookDownloaded(bookId: bookId) else { return nil }
    let file = bookDirectory(instanceId: instanceId, bookId: bookId).appendingPathComponent(
      "book.epub")
    return FileManager.default.fileExists(atPath: file.path) ? file : nil
  }

  // MARK: - Resource Fetchers (Offline-Aware)

  func getBookPages(bookId: String) async throws -> [BookPage] {
    if let pages = await DatabaseOperator.shared.fetchPages(id: bookId) {
      return pages
    }
    throw APIError.offline
  }

  func getBookTOC(bookId: String) async throws -> [ReaderTOCEntry] {
    if let toc = await DatabaseOperator.shared.fetchTOC(id: bookId) {
      return toc
    }
    throw APIError.offline
  }

  func getNextBook(bookId: String, readListId: String? = nil) async -> Book? {
    let instanceId = AppConfig.currentInstanceId
    return await DatabaseOperator.shared.getNextBook(
      instanceId: instanceId, bookId: bookId, readListId: readListId)
  }

  func getPreviousBook(bookId: String, readListId: String? = nil) async -> Book? {
    let instanceId = AppConfig.currentInstanceId
    return await DatabaseOperator.shared.getPreviousBook(
      instanceId: instanceId, bookId: bookId, readListId: readListId)
  }

  func updateLocalProgress(bookId: String, page: Int, completed: Bool) async {
    await DatabaseOperator.shared.updateReadingProgress(
      bookId: bookId, page: page, completed: completed)
    await DatabaseOperator.shared.commit()
  }

  private func calculateDirectorySize(_ url: URL) throws -> Int64 {
    let contents = try FileManager.default.contentsOfDirectory(
      at: url, includingPropertiesForKeys: [.fileSizeKey])
    var total: Int64 = 0
    for file in contents {
      let attrs = try file.resourceValues(forKeys: [.fileSizeKey])
      total += Int64(attrs.fileSize ?? 0)
    }
    return total
  }

  // MARK: - Private Helpers

  private func removeActiveTask(_ bookId: String) {
    activeTasks[bookId]?.cancel()
    activeTasks[bookId] = nil
    Task { @MainActor in
      DownloadProgressTracker.shared.clearProgress(bookId: bookId)
    }
  }

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

  // MARK: - Background Download Handlers (iOS only)

  #if os(iOS)
    /// Track pending background downloads per book
    private var pendingBackgroundPages: [String: Set<Int>] = [:]  // bookId -> pending page numbers
    private var backgroundDownloadInfo:
      [String: (
        instanceId: String, seriesTitle: String, bookInfo: String, isEpub: Bool, totalPages: Int
      )] = [:]
    private func handleBackgroundDownloadComplete(
      bookId: String, pageNumber: Int?, fileURL: URL
    ) async {
      let backgroundTaskId = await startBackgroundTask()
      defer {
        Task {
          await endBackgroundTask(backgroundTaskId)
        }
      }

      guard let info = backgroundDownloadInfo[bookId] else { return }

      if info.isEpub {
        // EPUB download complete
        logger.info("✅ Background EPUB download complete for book: \(bookId)")
      } else if let pageNumber = pageNumber {
        // Page download complete
        pendingBackgroundPages[bookId]?.remove(pageNumber)

        // Update progress
        let completed = info.totalPages - (pendingBackgroundPages[bookId]?.count ?? 0)
        let progress = Double(completed) / Double(info.totalPages)
        let pendingBooks = await DatabaseOperator.shared.fetchPendingBooks()
        let failedCount = await DatabaseOperator.shared.fetchFailedBooksCount(
          instanceId: info.instanceId)

        await MainActor.run {
          DownloadProgressTracker.shared.updateProgress(bookId: bookId, value: progress)
        }

        // Update Live Activity
        await LiveActivityManager.shared.updateActivity(
          seriesTitle: info.seriesTitle,
          bookInfo: info.bookInfo,
          progress: progress,
          pendingCount: pendingBooks.count,
          failedCount: failedCount
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

      guard let info = backgroundDownloadInfo[bookId] else { return }

      // Check if this is a network error while we're now offline
      let isNetworkError = isNetworkRelatedError(error)
      if isNetworkError && AppConfig.isOffline {
        // Network error caused offline mode switch - keep as pending for retry
        logger.info("⚠️ Background download paused due to network error: \(bookId)")
        return
      }

      // Mark book as failed
      logger.error("❌ Background download failed for \(bookId): \(error)")
      await DatabaseOperator.shared.updateBookDownloadStatus(
        bookId: bookId,
        instanceId: info.instanceId,
        status: .failed(error: error.localizedDescription)
      )
      await DatabaseOperator.shared.commit()

      // Cancel remaining downloads for this book
      await BackgroundDownloadManager.shared.cancelDownloads(forBookId: bookId)
      pendingBackgroundPages.removeValue(forKey: bookId)
      backgroundDownloadInfo.removeValue(forKey: bookId)
      removeActiveTask(bookId)

      // Update Live Activity or end if no more pending
      let pendingBooks = await DatabaseOperator.shared.fetchPendingBooks()
      let failedCount = await DatabaseOperator.shared.fetchFailedBooksCount(
        instanceId: info.instanceId)

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
      guard let info = backgroundDownloadInfo[bookId] else { return }

      let bookDir = bookDirectory(instanceId: info.instanceId, bookId: bookId)

      do {
        let totalSize = try calculateDirectorySize(bookDir)
        await DatabaseOperator.shared.updateBookDownloadStatus(
          bookId: bookId,
          instanceId: info.instanceId,
          status: .downloaded,
          downloadedSize: totalSize
        )
        await DatabaseOperator.shared.commit()
        await clearCachesAfterDownload(bookId: bookId, isEpub: info.isEpub)
        logger.info("✅ All background downloads complete for book: \(bookId)")
      } catch {
        logger.error("❌ Failed to calculate size for book \(bookId): \(error)")
      }

      // Cleanup tracking
      pendingBackgroundPages.removeValue(forKey: bookId)
      backgroundDownloadInfo.removeValue(forKey: bookId)
      removeActiveTask(bookId)

      // Clear progress notification if no more pending downloads
      let pendingBooks = await DatabaseOperator.shared.fetchPendingBooks()
      if pendingBooks.isEmpty {
        let failedCount = await DatabaseOperator.shared.fetchFailedBooksCount(
          instanceId: info.instanceId)
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
          // End Live Activity when all downloads complete successfully
          await LiveActivityManager.shared.endActivity()
        }
      }

      // Trigger next download
      await syncDownloadQueue(instanceId: info.instanceId)
    }
  #endif

  // MARK: - Download Logic

  private func downloadEpub(bookId: String, to bookDir: URL) async throws {
    // Save pages metadata to DB
    let pages = try await BookService.shared.getBookPages(id: bookId)
    await DatabaseOperator.shared.updateBookPages(bookId: bookId, pages: pages)
    await DatabaseOperator.shared.commit()

    // Save TOC if it exists to DB
    if let manifest = try? await BookService.shared.getBookManifest(id: bookId) {
      let toc = await ReaderManifestService(bookId: bookId).parseTOC(manifest: manifest)
      await DatabaseOperator.shared.updateBookTOC(bookId: bookId, toc: toc)
      await DatabaseOperator.shared.commit()
    }

    let destination = bookDir.appendingPathComponent("book.epub")
    if await copyCachedEpubIfAvailable(bookId: bookId, destination: destination) {
      return
    }

    let data = try await BookService.shared.downloadEpubFile(bookId: bookId)
    try data.write(to: destination)
  }

  private func downloadPages(bookId: String, to bookDir: URL) async throws {
    let pages = try await BookService.shared.getBookPages(id: bookId)

    // Save pages metadata to DB
    await DatabaseOperator.shared.updateBookPages(bookId: bookId, pages: pages)
    await DatabaseOperator.shared.commit()

    // Save TOC to DB
    if let manifest = try? await BookService.shared.getBookManifest(id: bookId) {
      let toc = await ReaderManifestService(bookId: bookId).parseTOC(manifest: manifest)
      await DatabaseOperator.shared.updateBookTOC(bookId: bookId, toc: toc)
      await DatabaseOperator.shared.commit()
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
      return true
    } catch {
      logger.error("❌ Failed to copy cached page for book \(bookId) page \(page.number): \(error)")
      return false
    }
  }

  private func copyCachedEpubIfAvailable(
    bookId: String,
    destination: URL
  ) async -> Bool {
    if FileManager.default.fileExists(atPath: destination.path) {
      return true
    }

    guard let cachedURL = await BookFileCache.shared.cachedEpubFileURL(bookId: bookId) else {
      return false
    }

    do {
      try FileManager.default.copyItem(at: cachedURL, to: destination)
      return true
    } catch {
      logger.error("❌ Failed to copy cached EPUB for book \(bookId): \(error)")
      return false
    }
  }

  private func clearCachesAfterDownload(bookId: String, isEpub: Bool) async {
    await ImageCache.clearDiskCache(forBookId: bookId)
    if isEpub {
      await BookFileCache.clearDiskCache(forBookId: bookId)
    }
  }
}

// MARK: - Helper Extension

extension Book {
  var downloadInfo: DownloadInfo {
    DownloadInfo(
      bookId: id,
      seriesTitle: oneshot ? String(localized: "Oneshot") : seriesTitle,
      bookInfo: oneshot ? "\(metadata.title)" : "#\(metadata.number) - \(metadata.title)",
      isEpub: media.mediaProfile == .epub,
      epubDivinaCompatible: media.epubDivinaCompatible ?? false
    )
  }
}
