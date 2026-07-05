//
// OfflineCoverSyncService.swift
//
//

import Foundation

typealias OfflineCoverSyncProgressHandler = @MainActor @Sendable (OfflineCoverSyncProgress) -> Void

actor OfflineCoverSyncService {
  static let shared = OfflineCoverSyncService()

  private let logger = AppLogger(.offline)
  private let cachedProgressReportInterval: TimeInterval = 0.15
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
    var cachedThumbnailIds = await ThumbnailCache.shared.cachedCoverThumbnailIds(
      matching: targetIdsByType(targets)
    )
    var summary = OfflineCoverSyncSummary()
    summary.totalCount = targets.count
    await reportProgress(summary: summary, onProgress: onProgress)
    var lastCachedProgressReportAt = Date()

    for target in targets {
      if shouldStopSync(instanceId: instanceId) {
        return await stopSync(summary: summary, onProgress: onProgress)
      }

      if cachedThumbnailIds[target.type]?.contains(target.thumbnailId) == true {
        summary.existingCount += 1
        summary.checkedCount += 1
        await reportCachedProgressIfNeeded(
          summary: summary,
          lastReportAt: &lastCachedProgressReportAt,
          onProgress: onProgress
        )
        continue
      }

      do {
        let result = try await ThumbnailCache.shared.ensureMissingThumbnail(
          id: target.thumbnailId,
          type: target.type
        )

        switch result {
        case .cached:
          cachedThumbnailIds[target.type, default: []].insert(target.thumbnailId)
          summary.existingCount += 1
          summary.checkedCount += 1
          await reportCachedProgressIfNeeded(
            summary: summary,
            lastReportAt: &lastCachedProgressReportAt,
            onProgress: onProgress
          )
        case .stored:
          cachedThumbnailIds[target.type, default: []].insert(target.thumbnailId)
          summary.storedCount += 1
          summary.checkedCount += 1
          await reportProgress(summary: summary, onProgress: onProgress)
        case .cacheLimitReached:
          summary.stoppedAtCacheLimit = true
          logger.info("⏸️ Stopped offline cover sync because cover cache reached its maximum size")
          await reportProgress(summary: summary, onProgress: onProgress)
          return summary
        }
      } catch is CancellationError {
        return await stopSync(summary: summary, onProgress: onProgress)
      } catch APIError.offline {
        return await stopSync(summary: summary, onProgress: onProgress)
      } catch APIError.networkError(_, _) {
        return await stopSync(summary: summary, onProgress: onProgress)
      } catch let error as APIError where shouldStopAfterAPIWideFailure(error) {
        await reportProgress(summary: summary, onProgress: onProgress)
        logger.warning("⏹️ Offline cover sync stopped by API-wide failure: \(error.description)")
        throw error
      } catch {
        if shouldStopSync(instanceId: instanceId) {
          return await stopSync(summary: summary, onProgress: onProgress)
        }

        summary.checkedCount += 1
        summary.failedCount += 1
        logger.warning(
          "⚠️ Failed to sync offline cover for \(target.type.rawValue) \(target.thumbnailId): \(error.localizedDescription)"
        )
        await reportProgress(summary: summary, onProgress: onProgress)
      }
    }

    await reportProgress(summary: summary, onProgress: onProgress)
    logger.info(
      "✅ Offline cover sync finished: checked=\(summary.checkedCount), existing=\(summary.existingCount), stored=\(summary.storedCount), failed=\(summary.failedCount)"
    )
    return summary
  }

  private func shouldStopSync(instanceId: String) -> Bool {
    Task.isCancelled || AppConfig.isOffline || AppConfig.current.instanceId != instanceId
  }

  private func shouldStopAfterAPIWideFailure(_ error: APIError) -> Bool {
    switch error {
    case .unauthorized, .forbidden, .tooManyRequests, .serverError:
      return true
    default:
      return false
    }
  }

  private func targetIdsByType(_ targets: [OfflineCoverSyncTarget]) -> [ThumbnailType: Set<String>] {
    var idsByType: [ThumbnailType: Set<String>] = [:]
    for target in targets {
      idsByType[target.type, default: []].insert(target.thumbnailId)
    }
    return idsByType
  }

  private func reportCachedProgressIfNeeded(
    summary: OfflineCoverSyncSummary,
    lastReportAt: inout Date,
    onProgress: OfflineCoverSyncProgressHandler?
  ) async {
    let now = Date()
    guard
      summary.checkedCount == summary.totalCount
        || now.timeIntervalSince(lastReportAt) >= cachedProgressReportInterval
    else { return }

    lastReportAt = now
    await reportProgress(summary: summary, onProgress: onProgress)
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
