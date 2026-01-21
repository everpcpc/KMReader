//
//  ProgressSyncService.swift
//  KMReader
//
//  Created by Komga iOS Client
//

import Foundation
import OSLog

@globalActor
actor ProgressSyncService {
  static let shared = ProgressSyncService()

  private let logger = AppLogger(.sync)
  private var isSyncing = false

  private init() {}

  func syncPendingProgress(instanceId: String) async {
    guard !isSyncing else {
      logger.info("⏭️ Progress sync already in progress, skipping")
      return
    }

    guard !AppConfig.isOffline else {
      logger.info("⏭️ Still offline, skipping progress sync")
      return
    }

    isSyncing = true
    defer { isSyncing = false }

    let pending = await DatabaseOperator.shared.fetchPendingProgress(instanceId: instanceId)

    guard !pending.isEmpty else {
      logger.info("✅ No pending progress to sync")
      return
    }

    logger.info("🔄 Syncing \(pending.count) pending progress items")

    var successCount = 0
    var failureCount = 0
    var completedBookIds = Set<String>()

    for item in pending {
      do {
        try await syncProgressItem(item)
        await DatabaseOperator.shared.deletePendingProgress(id: item.id)
        await DatabaseOperator.shared.commit()
        successCount += 1

        if item.completed {
          completedBookIds.insert(item.bookId)
        }
      } catch {
        logger.error(
          "❌ Failed to sync progress for book \(item.bookId): \(error.localizedDescription)")
        failureCount += 1
      }
    }

    // Batch sync books and series after individual progress items are processed
    var completedSeriesIds = Set<String>()
    for bookId in completedBookIds {
      if let book = try? await SyncService.shared.syncBook(bookId: bookId) {
        completedSeriesIds.insert(book.seriesId)
      }
    }

    for seriesId in completedSeriesIds {
      _ = try? await SyncService.shared.syncSeriesDetail(seriesId: seriesId)
    }

    if successCount > 0 {
      logger.info("✅ Successfully synced \(successCount) progress items")
    }

    if failureCount > 0 {
      logger.warning("⚠️ Failed to sync \(failureCount) progress items, will retry later")
    }
  }

  private func syncProgressItem(_ item: PendingProgressSummary) async throws {
    // Check if this is EPUB progression or page-based progress
    if let progressionData = item.progressionData {
      // EPUB progression - decode on MainActor
      let progression = try await MainActor.run {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(R2Progression.self, from: progressionData)
      }

      try await BookService.shared.updateWebPubProgression(
        bookId: item.bookId,
        progression: progression
      )
      logger.debug("✅ Synced EPUB progression for book \(item.bookId)")

    } else {
      // Page-based progress
      try await BookService.shared.updatePageReadProgress(
        bookId: item.bookId,
        page: item.page,
        completed: item.completed
      )
      logger.debug("✅ Synced page progress for book \(item.bookId) - page \(item.page)")
    }
  }
}
