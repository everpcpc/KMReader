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
    logger.debug("🚀 Starting pending progress sync for instance \(instanceId)")

    guard !isSyncing else {
      logger.info("⏭️ Progress sync already in progress, skipping")
      return
    }

    guard !AppConfig.isOffline else {
      logger.info("⏭️ Still offline, skipping progress sync")
      return
    }

    isSyncing = true
    defer {
      isSyncing = false
      logger.debug("🏁 Finished pending progress sync for instance \(instanceId)")
    }

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
      logger.debug(
        "🧾 Sync pending item id=\(item.id), book=\(item.bookId), page=\(item.page), completed=\(item.completed), hasProgressionData=\(item.progressionData != nil), createdAt=\(item.createdAt.ISO8601Format())"
      )
      do {
        try await syncProgressItem(item)
        await DatabaseOperator.shared.deletePendingProgress(id: item.id)
        await DatabaseOperator.shared.commit()
        successCount += 1
        logger.debug("🧹 Removed synced pending item id=\(item.id)")

        if item.completed {
          completedBookIds.insert(item.bookId)
        }
      } catch {
        logger.error(
          "❌ Failed to sync progress for book \(item.bookId) (pending id=\(item.id)): \(error.localizedDescription)"
        )
        failureCount += 1
      }
    }

    // Batch sync books and series after individual progress items are processed
    var completedSeriesIds = Set<String>()
    for bookId in completedBookIds {
      logger.debug("🔄 Refreshing completed book after progress sync: book=\(bookId)")
      if let book = try? await SyncService.shared.syncBook(bookId: bookId) {
        completedSeriesIds.insert(book.seriesId)
      }
    }

    for seriesId in completedSeriesIds {
      logger.debug("🔄 Refreshing series after completed book sync: series=\(seriesId)")
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
      logger.debug(
        "📤 Sync EPUB pending progression for book \(item.bookId), payloadBytes=\(progressionData.count)"
      )
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
      logger.debug(
        "📤 Sync page pending progress for book \(item.bookId), page=\(item.page), completed=\(item.completed)"
      )
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
