//
//  BackgroundDownloadManager.swift
//  KMReader
//
//  Manages background downloads using URLSession background configuration.
//

import Foundation
import OSLog

#if !os(tvOS)

  /// Information about a download task, persisted to UserDefaults for session reconnection
  struct BackgroundDownloadTaskInfo: Codable {
    let bookId: String
    let instanceId: String
    let pageNumber: Int?  // nil for EPUB downloads
    let isEpub: Bool
    let destinationPath: String
  }

  /// Manages background downloads that continue when app is backgrounded
  final class BackgroundDownloadManager: NSObject {
    static let shared = BackgroundDownloadManager()

    private let logger = AppLogger(.offline)
    private let sessionIdentifier = "com.kmreader.offline.background"

    /// Completion handler provided by iOS when app is woken for background events
    var backgroundCompletionHandler: (() -> Void)?

    /// Track active download tasks by task identifier
    private var activeTasks: [Int: BackgroundDownloadTaskInfo] = [:]

    /// Callbacks for download completion
    var onDownloadComplete: ((String, Int?, URL) -> Void)?  // bookId, pageNumber?, fileURL
    var onDownloadFailed: ((String, Int?, Error) -> Void)?  // bookId, pageNumber?, error
    var onAllDownloadsComplete: ((String) -> Void)?  // bookId

    private lazy var backgroundSession: URLSession = {
      let config = URLSessionConfiguration.background(withIdentifier: sessionIdentifier)
      config.isDiscretionary = false  // download immediately, not when optimal
      config.sessionSendsLaunchEvents = true  // wake app on completion
      config.allowsCellularAccess = true
      config.httpMaximumConnectionsPerHost = 3

      // Add auth headers
      var headers: [String: String] = [:]
      if AppConfig.current.authMethod == .apiKey && !AppConfig.current.authToken.isEmpty {
        headers["X-API-Key"] = AppConfig.current.authToken
      }
      if !headers.isEmpty {
        config.httpAdditionalHeaders = headers
      }

      return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()

    private override init() {
      super.init()
      loadTaskInfo()
    }

    // MARK: - Public API

    /// Reconnect to the background session after app relaunch
    func reconnectSession() {
      // Accessing backgroundSession triggers the lazy initialization
      // which reconnects to the background session
      _ = backgroundSession
      logger.info("🔄 Reconnected to background session")
    }

    /// Start a background download for an EPUB file
    func downloadEpub(
      bookId: String,
      instanceId: String,
      url: URL,
      destinationPath: String
    ) {
      var request = URLRequest(url: url)
      addAuthHeaders(to: &request)

      let task = backgroundSession.downloadTask(with: request)
      let taskInfo = BackgroundDownloadTaskInfo(
        bookId: bookId,
        instanceId: instanceId,
        pageNumber: nil,
        isEpub: true,
        destinationPath: destinationPath
      )

      activeTasks[task.taskIdentifier] = taskInfo
      saveTaskInfo()

      logger.info("⬇️ Starting background EPUB download for book: \(bookId)")
      task.resume()
    }

    /// Start a background download for a page image
    func downloadPage(
      bookId: String,
      instanceId: String,
      pageNumber: Int,
      url: URL,
      destinationPath: String
    ) {
      var request = URLRequest(url: url)
      addAuthHeaders(to: &request)

      let task = backgroundSession.downloadTask(with: request)
      let taskInfo = BackgroundDownloadTaskInfo(
        bookId: bookId,
        instanceId: instanceId,
        pageNumber: pageNumber,
        isEpub: false,
        destinationPath: destinationPath
      )

      activeTasks[task.taskIdentifier] = taskInfo
      saveTaskInfo()

      logger.debug("⬇️ Starting background page download: \(bookId) page \(pageNumber)")
      task.resume()
    }

    /// Cancel all downloads for a specific book
    func cancelDownloads(forBookId bookId: String) {
      backgroundSession.getAllTasks { [weak self] tasks in
        guard let self = self else { return }
        Task { @MainActor in
          for task in tasks {
            if let info = self.activeTasks[task.taskIdentifier], info.bookId == bookId {
              task.cancel()
              self.activeTasks.removeValue(forKey: task.taskIdentifier)
            }
          }
          self.saveTaskInfo()
          self.logger.info("⛔ Cancelled all background downloads for book: \(bookId)")
        }
      }
    }

    /// Cancel all active downloads
    func cancelAllDownloads() {
      backgroundSession.getAllTasks { [weak self] tasks in
        guard let self = self else { return }
        Task { @MainActor in
          for task in tasks {
            task.cancel()
          }
          self.activeTasks.removeAll()
          self.saveTaskInfo()
          self.logger.info("⛔ Cancelled all background downloads")
        }
      }
    }

    /// Check if there are active downloads for a book
    func hasActiveDownloads(forBookId bookId: String) -> Bool {
      activeTasks.values.contains { $0.bookId == bookId }
    }

    // MARK: - Private Helpers

    private func addAuthHeaders(to request: inout URLRequest) {
      switch AppConfig.current.authMethod {
      case .basicAuth:
        // For basic auth, cookies from the shared session should work
        break
      case .apiKey:
        if !AppConfig.current.authToken.isEmpty {
          request.setValue(AppConfig.current.authToken, forHTTPHeaderField: "X-API-Key")
        }
      }
    }

    private func saveTaskInfo() {
      let encoder = JSONEncoder()
      if let data = try? encoder.encode(activeTasks) {
        AppConfig.backgroundDownloadTasksData = data
      }
    }

    private func loadTaskInfo() {
      guard let data = AppConfig.backgroundDownloadTasksData,
        let tasks = try? JSONDecoder().decode([Int: BackgroundDownloadTaskInfo].self, from: data)
      else {
        return
      }
      activeTasks = tasks
      logger.info("📂 Loaded \(tasks.count) pending background download tasks")
    }

    private func handleDownloadComplete(taskIdentifier: Int, location: URL) {
      guard let taskInfo = activeTasks[taskIdentifier] else {
        logger.warning("⚠️ Completed download for unknown task: \(taskIdentifier)")
        return
      }

      // Move file to destination
      let destinationURL = URL(fileURLWithPath: taskInfo.destinationPath)
      let destinationDir = destinationURL.deletingLastPathComponent()

      do {
        // Create directory if needed
        if !FileManager.default.fileExists(atPath: destinationDir.path) {
          try FileManager.default.createDirectory(
            at: destinationDir, withIntermediateDirectories: true)
        }

        // Remove existing file if present
        if FileManager.default.fileExists(atPath: destinationURL.path) {
          try FileManager.default.removeItem(at: destinationURL)
        }

        // Move downloaded file
        try FileManager.default.moveItem(at: location, to: destinationURL)

        logger.info(
          "✅ Background download complete: \(taskInfo.bookId) page \(taskInfo.pageNumber ?? -1)")

        // Notify completion
        onDownloadComplete?(taskInfo.bookId, taskInfo.pageNumber, destinationURL)

      } catch {
        logger.error(
          "❌ Failed to move downloaded file: \(error.localizedDescription)")
        onDownloadFailed?(taskInfo.bookId, taskInfo.pageNumber, error)
      }

      // Remove from active tasks
      activeTasks.removeValue(forKey: taskIdentifier)
      saveTaskInfo()

      // Check if all downloads for this book are complete
      if !hasActiveDownloads(forBookId: taskInfo.bookId) {
        onAllDownloadsComplete?(taskInfo.bookId)
      }
    }

    private func handleDownloadError(taskIdentifier: Int, error: Error) {
      guard let taskInfo = activeTasks[taskIdentifier] else {
        return
      }

      logger.error(
        "❌ Background download failed for \(taskInfo.bookId): \(error.localizedDescription)")

      onDownloadFailed?(taskInfo.bookId, taskInfo.pageNumber, error)

      activeTasks.removeValue(forKey: taskIdentifier)
      saveTaskInfo()
    }
  }

  // MARK: - URLSessionDownloadDelegate

  extension BackgroundDownloadManager: URLSessionDownloadDelegate {

    nonisolated func urlSession(
      _ session: URLSession,
      downloadTask: URLSessionDownloadTask,
      didFinishDownloadingTo location: URL
    ) {
      Task { @MainActor in
        self.handleDownloadComplete(taskIdentifier: downloadTask.taskIdentifier, location: location)
      }
    }

    nonisolated func urlSession(
      _ session: URLSession,
      task: URLSessionTask,
      didCompleteWithError error: Error?
    ) {
      Task { @MainActor in
        if let error = error {
          self.handleDownloadError(taskIdentifier: task.taskIdentifier, error: error)
        }

        // Call the background completion handler if all tasks are done
        if self.activeTasks.isEmpty, let handler = self.backgroundCompletionHandler {
          handler()
          self.backgroundCompletionHandler = nil
          self.logger.info("✅ Background session events processed")
        }
      }
    }

    nonisolated func urlSession(
      _ session: URLSession,
      downloadTask: URLSessionDownloadTask,
      didWriteData bytesWritten: Int64,
      totalBytesWritten: Int64,
      totalBytesExpectedToWrite: Int64
    ) {
      Task { @MainActor in
        guard let taskInfo = self.activeTasks[downloadTask.taskIdentifier] else { return }

        // Only update progress for EPUB downloads (single file)
        // Page downloads are tracked by completed count in OfflineManager
        if taskInfo.isEpub, totalBytesExpectedToWrite > 0 {
          let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
          DownloadProgressTracker.shared.updateProgress(bookId: taskInfo.bookId, value: progress)
        }
      }
    }

    nonisolated func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
      // Called when all background session events have been delivered
      Task { @MainActor in
        if let handler = self.backgroundCompletionHandler {
          handler()
          self.backgroundCompletionHandler = nil
          self.logger.info("✅ All background session events finished")
        }
      }
    }
  }

#endif
