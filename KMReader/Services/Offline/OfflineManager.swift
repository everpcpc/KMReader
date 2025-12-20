//
//  OfflineManager.swift
//  KMReader
//
//  Created by Komga iOS Client
//

import Foundation
import OSLog
import UniformTypeIdentifiers

/// Simple Sendable struct for download info.
struct DownloadInfo: Sendable {
  let bookId: String
  let bookName: String
  let isEpub: Bool
}

/// Actor for managing offline book downloads with proper thread isolation.
/// Download status is persisted in SwiftData via KomgaBook.downloadStatus.
actor OfflineManager {
  static let shared = OfflineManager()

  private var activeTasks: [String: Task<Void, Never>] = [:]

  private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "KMReader", category: "OfflineManager")

  private init() {}

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
    await MainActor.run {
      KomgaBookStore.shared.getDownloadStatus(bookId: bookId)
    }
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
    case .downloading, .pending:
      await cancelDownload(bookId: info.bookId)
    case .notDownloaded, .failed:
      await MainActor.run {
        KomgaBookStore.shared.updateDownloadStatus(
          bookId: info.bookId,
          status: .pending,
          downloadAt: .now
        )
      }
      await syncDownloadQueue(instanceId: instanceId)
    }
  }

  func deleteBook(instanceId: String, bookId: String) async {
    await cancelDownload(bookId: bookId)
    let dir = bookDirectory(instanceId: instanceId, bookId: bookId)

    // Update SwiftData first
    await MainActor.run {
      KomgaBookStore.shared.updateDownloadStatus(bookId: bookId, status: .notDownloaded)
    }

    // Then delete files
    Task.detached { [logger] in
      do {
        if FileManager.default.fileExists(atPath: dir.path) {
          try FileManager.default.removeItem(at: dir)
        }
        logger.info("Deleted offline book: \(bookId)")
      } catch {
        logger.error("Failed to delete book \(bookId): \(error)")
      }
    }
  }

  /// Cancel all active downloads (used during cleanup).
  func cancelAllDownloads() async {
    for (bookId, task) in activeTasks {
      task.cancel()
      await MainActor.run {
        KomgaBookStore.shared.updateDownloadStatus(bookId: bookId, status: .notDownloaded)
      }
    }
    activeTasks.removeAll()
  }

  func syncDownloadQueue(instanceId: String) async {
    // Check if paused
    guard !AppConfig.offlinePaused else { return }

    // Only allow one download at a time
    guard activeTasks.isEmpty else { return }

    let pending = await MainActor.run {
      KomgaBookStore.shared.fetchPendingBooks(limit: 1)
    }

    guard let nextBook = pending.first else { return }

    await startDownload(instanceId: instanceId, info: nextBook.downloadInfo)
  }

  private func startDownload(instanceId: String, info: DownloadInfo) async {
    guard activeTasks[info.bookId] == nil else { return }

    // Mark as downloading in SwiftData
    await MainActor.run {
      KomgaBookStore.shared.updateDownloadStatus(bookId: info.bookId, status: .downloading(progress: 0.0))
    }

    let bookDir = bookDirectory(instanceId: instanceId, bookId: info.bookId)

    activeTasks[info.bookId] = Task { [weak self, logger] in
      guard let self else { return }
      do {
        logger.info("Starting download for book: \(info.bookName) (\(info.bookId))")

        if info.isEpub {
          try await downloadEpub(bookId: info.bookId, to: bookDir)
        } else {
          try await downloadPages(bookId: info.bookId, to: bookDir)
        }

        // Mark complete in SwiftData
        let totalSize = try await self.calculateDirectorySize(bookDir)
        await MainActor.run {
          KomgaBookStore.shared.updateDownloadStatus(
            bookId: info.bookId, status: .downloaded, downloadedSize: totalSize)
        }
        await removeActiveTask(info.bookId)
        logger.info("Download complete for book: \(info.bookId)")

        // Trigger next download
        await syncDownloadQueue(instanceId: instanceId)

      } catch {
        // Cleanup on failure
        try? FileManager.default.removeItem(at: bookDir)

        if Task.isCancelled {
          logger.info("Download cancelled for book: \(info.bookId)")
        } else {
          logger.error("Download failed for book \(info.bookId): \(error)")
          await MainActor.run {
            KomgaBookStore.shared.updateDownloadStatus(
              bookId: info.bookId,
              status: .failed(error: error.localizedDescription)
            )
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
    await MainActor.run {
      KomgaBookStore.shared.updateDownloadStatus(bookId: bookId, status: .notDownloaded)
    }
  }

  // MARK: - Accessors for Reader

  func getOfflinePageImageURL(instanceId: String, bookId: String, pageNumber: Int, fileExtension: String) async -> URL? {
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
    let file = bookDirectory(instanceId: instanceId, bookId: bookId).appendingPathComponent("book.epub")
    return FileManager.default.fileExists(atPath: file.path) ? file : nil
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
    activeTasks[bookId] = nil
  }

  // MARK: - Download Logic

  private func downloadEpub(bookId: String, to bookDir: URL) async throws {
    let data = try await BookService.shared.downloadEpubFile(bookId: bookId)
    let dest = bookDir.appendingPathComponent("book.epub")
    try data.write(to: dest)
  }

  private func downloadPages(bookId: String, to bookDir: URL) async throws {
    let pages = try await BookService.shared.getBookPages(id: bookId)
    let total = Double(pages.count)

    try await withThrowingTaskGroup(of: Void.self) { group in
      var completedCount = 0
      let maxConcurrent = 4
      var active = 0
      var iterator = pages.makeIterator()

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
        await MainActor.run {
          KomgaBookStore.shared.updateDownloadStatus(bookId: bookId, status: .downloading(progress: progress))
        }

        submitNext()
      }
    }
  }
}

// MARK: - Helper Extension

extension Book {
  var downloadInfo: DownloadInfo {
    DownloadInfo(
      bookId: id,
      bookName: name,
      isEpub: media.mediaProfile == .epub
    )
  }
}
