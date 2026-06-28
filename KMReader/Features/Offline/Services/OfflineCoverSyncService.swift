//
// OfflineCoverSyncService.swift
//
//

import Foundation

typealias OfflineCoverSyncProgressHandler = @MainActor @Sendable (OfflineCoverSyncProgress) -> Void

actor OfflineCoverSyncService {
  static let shared = OfflineCoverSyncService()

  private let logger = AppLogger(.offline)
  private var isRunning = false

  private init() {}

  func syncMissingCovers(
    instanceId: String,
    libraryIds: [String] = [],
    onProgress: OfflineCoverSyncProgressHandler? = nil
  ) async throws -> OfflineCoverSyncSummary {
    guard !instanceId.isEmpty else { return OfflineCoverSyncSummary() }
    guard !isRunning else {
      throw AppErrorType.operationNotAllowed(message: "Cover sync is already running")
    }

    isRunning = true
    defer { isRunning = false }

    let database = try await DatabaseOperator.database()
    let targets = try await database.fetchOfflineCoverSyncTargets(
      instanceId: instanceId,
      libraryIds: libraryIds
    )
    var summary = OfflineCoverSyncSummary()
    summary.totalCount = targets.count
    await reportProgress(summary: summary, onProgress: onProgress)

    for target in targets {
      if shouldStopSync(instanceId: instanceId) {
        return await stopSync(summary: summary, onProgress: onProgress)
      }

      do {
        let result = try await ThumbnailCache.shared.ensureMissingThumbnail(
          id: target.thumbnailId,
          type: target.type
        )

        switch result {
        case .cached:
          summary.existingCount += 1
        case .stored:
          summary.storedCount += 1
        case .cacheLimitReached:
          summary.stoppedAtCacheLimit = true
          logger.info("⏸️ Stopped offline cover sync because cover cache reached its maximum size")
          await reportProgress(summary: summary, onProgress: onProgress)
          return summary
        }
        summary.checkedCount += 1
      } catch is CancellationError {
        return await stopSync(summary: summary, onProgress: onProgress)
      } catch APIError.offline {
        return await stopSync(summary: summary, onProgress: onProgress)
      } catch {
        if shouldStopSync(instanceId: instanceId) {
          return await stopSync(summary: summary, onProgress: onProgress)
        }

        summary.checkedCount += 1
        summary.failedCount += 1
        logger.warning(
          "⚠️ Failed to sync offline cover for \(target.type.rawValue) \(target.thumbnailId): \(error.localizedDescription)"
        )
      }
      await reportProgress(summary: summary, onProgress: onProgress)
    }

    logger.info(
      "✅ Offline cover sync finished: checked=\(summary.checkedCount), existing=\(summary.existingCount), stored=\(summary.storedCount), failed=\(summary.failedCount)"
    )
    return summary
  }

  private func shouldStopSync(instanceId: String) -> Bool {
    Task.isCancelled || AppConfig.isOffline || AppConfig.current.instanceId != instanceId
  }

  private func stopSync(
    summary: OfflineCoverSyncSummary,
    onProgress: OfflineCoverSyncProgressHandler?
  ) async -> OfflineCoverSyncSummary {
    var summary = summary
    summary.wasCancelled = true
    await reportProgress(summary: summary, onProgress: onProgress)
    logger.info("⏹️ Offline cover sync cancelled")
    return summary
  }

  private func reportProgress(
    summary: OfflineCoverSyncSummary,
    onProgress: OfflineCoverSyncProgressHandler?
  ) async {
    await onProgress?(
      OfflineCoverSyncProgress(
        totalCount: summary.totalCount,
        checkedCount: summary.checkedCount,
        existingCount: summary.existingCount,
        storedCount: summary.storedCount,
        failedCount: summary.failedCount
      )
    )
  }
}
