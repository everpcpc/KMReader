//
//  OfflineManager.swift
//  KMReader
//
//  Created by Komga iOS Client
//

import Foundation
import OSLog
import Observation
import SwiftData
import UniformTypeIdentifiers

enum DownloadStatus: Equatable {
  case notDownloaded
  case downloading(progress: Double)
  case downloaded
  case failed(error: String)
}

@MainActor
@Observable
class OfflineManager {
  static let shared = OfflineManager()

  var downloadStatuses: [String: DownloadStatus] = [:]

  private let fileManager = FileManager.default
  private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "KMReader", category: "OfflineManager")
  private var activeTasks: [String: Task<Void, Never>] = [:]

  private init() {
    // We don't need to load metadata from disk anymore, we use SwiftData.
    // But we might want to check file consistency on startup?
    // For now, lazy load status.
  }

  // MARK: - Paths

  private func offlineDirectory() -> URL {
    let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("OfflineBooks", isDirectory: true)
    if !fileManager.fileExists(atPath: url.path) {
      try? fileManager.createDirectory(at: url, withIntermediateDirectories: true)
    }
    return url
  }

  private func bookDirectory(id: String) -> URL {
    let url = offlineDirectory().appendingPathComponent(id, isDirectory: true)
    if !fileManager.fileExists(atPath: url.path) {
      try? fileManager.createDirectory(at: url, withIntermediateDirectories: true)
    }
    return url
  }

  // MARK: - Public API

  func isBookDownloaded(bookId: String) -> Bool {
    if KomgaBookStore.shared.fetchBook(id: bookId) != nil {
      let dir = bookDirectory(id: bookId)
      // Simple check: does directory exist and have content?
      // This might be slow if called often.
      // Better: rely on memory state initialized from DB/Files.
      // But for now, let's check DB flag via Store if we expose it?
      // KomgaBookStore currently returns Book struct which doesn't have isDownloaded.
      // Let's add isDownloaded to Book struct? No, it's a local property.

      // Let's check file existence for now, it's robust.
      // Or check internal status map if populated.

      // Actually, let's use the file system as source of truth for "isDownloaded"
      // to avoid sync issues.
      let isEpub = fileManager.fileExists(atPath: dir.appendingPathComponent("book.epub").path)
      if isEpub { return true }

      // For images, check if directory has files?
      // Ideally we check for a "completed" marker file.
      return fileManager.fileExists(atPath: dir.appendingPathComponent("completed").path)
    }
    return false
  }

  func getDownloadStatus(for bookId: String) -> DownloadStatus {
    if let status = downloadStatuses[bookId] {
      return status
    }
    return isBookDownloaded(bookId: bookId) ? .downloaded : .notDownloaded
  }

  func toggleDownload(book: Book) {
    if isBookDownloaded(bookId: book.id) {
      deleteBook(bookId: book.id)
    } else {
      if case .downloading = getDownloadStatus(for: book.id) {
        cancelDownload(bookId: book.id)
      } else {
        startDownload(book: book)
      }
    }
  }

  func deleteBook(bookId: String) {
    cancelDownload(bookId: bookId)
    let dir = bookDirectory(id: bookId)
    do {
      if fileManager.fileExists(atPath: dir.path) {
        try fileManager.removeItem(at: dir)
      }
      downloadStatuses[bookId] = .notDownloaded
      updateKomgaBookStatus(bookId: bookId, isDownloaded: false)
      logger.info("Deleted offline book: \(bookId)")
    } catch {
      logger.error("Failed to delete book \(bookId): \(error)")
    }
  }

  func startDownload(book: Book) {
    guard activeTasks[book.id] == nil else { return }

    downloadStatuses[book.id] = .downloading(progress: 0.0)

    activeTasks[book.id] = Task {
      do {
        logger.info("Starting download for book: \(book.name) (\(book.id))")

        // 1. Handle based on media type
        if book.media.mediaProfile == .epub {
          try await downloadEpub(book: book)
        } else {
          try await downloadPages(book: book)
        }

        // 2. Mark Complete
        let dir = bookDirectory(id: book.id)
        fileManager.createFile(atPath: dir.appendingPathComponent("completed").path, contents: nil)

        downloadStatuses[book.id] = .downloaded
        updateKomgaBookStatus(bookId: book.id, isDownloaded: true)
        logger.info("Download complete for book: \(book.id)")

      } catch {
        if Task.isCancelled {
          logger.info("Download cancelled for book: \(book.id)")
          downloadStatuses[book.id] = .notDownloaded
        } else {
          logger.error("Download failed for book \(book.id): \(error)")
          downloadStatuses[book.id] = .failed(error: error.localizedDescription)
        }
        // Cleanup on failure
        try? fileManager.removeItem(at: bookDirectory(id: book.id))
        updateKomgaBookStatus(bookId: book.id, isDownloaded: false)
      }
      activeTasks[book.id] = nil
    }
  }

  func cancelDownload(bookId: String) {
    activeTasks[bookId]?.cancel()
    activeTasks[bookId] = nil
    downloadStatuses[bookId] = .notDownloaded
  }

  // MARK: - Accessors for Reader

  func getOfflinePageImageURL(bookId: String, page: BookPage) -> URL? {
    guard isBookDownloaded(bookId: bookId) else { return nil }
    let dir = bookDirectory(id: bookId)

    // Check for "page-{number}.ext"
    // We try to match known extensions or find the file
    let ext = page.detectedUTType?.preferredFilenameExtension ?? "jpg"
    let file = dir.appendingPathComponent("page-\(page.number).\(ext)")
    if fileManager.fileExists(atPath: file.path) {
      return file
    }
    // Fallback: iterate (slower but safer if extension mismatch)
    // Optimization: We should enforce extension when saving.
    return nil
  }

  func getOfflineEpubURL(bookId: String) -> URL? {
    guard isBookDownloaded(bookId: bookId) else { return nil }
    let file = bookDirectory(id: bookId).appendingPathComponent("book.epub")
    return fileManager.fileExists(atPath: file.path) ? file : nil
  }

  // MARK: - Internal Logic

  private func downloadEpub(book: Book) async throws {
    let data = try await BookService.shared.downloadEpubFile(bookId: book.id)
    let dest = bookDirectory(id: book.id).appendingPathComponent("book.epub")
    try data.write(to: dest)
  }

  private func downloadPages(book: Book) async throws {
    let pages = try await BookService.shared.getBookPages(id: book.id)
    let total = Double(pages.count)
    let bookId = book.id
    let bookDir = bookDirectory(id: bookId)
    let fm = FileManager.default

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

            if !fm.fileExists(atPath: dest.path) {
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
          self.downloadStatuses[book.id] = .downloading(progress: progress)
        }

        submitNext()
      }
    }
  }

  private func updateKomgaBookStatus(bookId: String, isDownloaded: Bool) {
    // We can use a private context to update the KomgaBook entity
    // Or notify SyncService?
    // For now, let's just log.
    // Ideally KomgaBookStore should expose a method to update local state.
  }
}
