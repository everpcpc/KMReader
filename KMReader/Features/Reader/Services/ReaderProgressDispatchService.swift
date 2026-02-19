//
//  ReaderProgressDispatchService.swift
//  KMReader
//

import Foundation

actor ReaderProgressDispatchService {
  static let shared = ReaderProgressDispatchService()

  private struct PageUpdate: Sendable {
    let bookId: String
    let version: UInt64
    let page: Int
    let completed: Bool
  }

  private struct EpubUpdate: Sendable {
    let bookId: String
    let version: UInt64
    let globalPageNumber: Int
    let progression: R2Progression
    let progressionData: Data?
  }

  private enum ProgressUpdateResult {
    case serverUpdated
    case offlineQueued
    case skipped
    case failed
  }

  typealias ProgressCheckpoint = [String: UInt64]

  private let logger = AppLogger(.reader)
  private let progressRequestTimeout: TimeInterval = 1
  private let timeoutRetryLimit = 2

  private var pendingPageUpdates: [String: PageUpdate] = [:]
  private var pageSendTasks: [String: Task<Void, Never>] = [:]
  private var localPageCacheTokenSeed: UInt64 = 0
  private var localPageCacheTokens: [String: UInt64] = [:]

  private var pendingEpubUpdates: [String: EpubUpdate] = [:]
  private var epubSendTasks: [String: Task<Void, Never>] = [:]

  private struct CheckpointWaiter {
    let checkpoint: ProgressCheckpoint
    let continuation: CheckedContinuation<Void, Never>
  }

  private var checkpointWaiters: [CheckpointWaiter] = []

  private var progressVersionSeedByBook: [String: UInt64] = [:]
  private var latestSubmittedProgressVersionByBook: [String: UInt64] = [:]
  private var latestSettledProgressVersionByBook: [String: UInt64] = [:]
  private var latestServerSyncedProgressVersionByBook: [String: UInt64] = [:]

  private init() {}

  func submitPageProgress(bookId: String, page: Int, completed: Bool) {
    let version = nextProgressVersion(for: bookId)
    let update = PageUpdate(bookId: bookId, version: version, page: page, completed: completed)
    pendingPageUpdates[bookId] = update
    logger.debug(
      "📝 [Progress/Page] Queued update: book=\(bookId), version=\(version), page=\(page), completed=\(completed)"
    )

    sendPendingPageProgress(for: bookId, trigger: "enqueue")
  }

  func flushPageProgress(bookId: String, snapshotPage: Int?, snapshotCompleted: Bool?) {
    guard !bookId.isEmpty else {
      logger.warning("⚠️ [Progress/Page] Skip flush: missing book ID")
      return
    }

    if pendingPageUpdates[bookId] == nil,
      let snapshotPage,
      let snapshotCompleted
    {
      let version = nextProgressVersion(for: bookId)
      let snapshot = PageUpdate(
        bookId: bookId,
        version: version,
        page: snapshotPage,
        completed: snapshotCompleted
      )
      pendingPageUpdates[bookId] = snapshot
      logger.debug(
        "🧲 [Progress/Page] Captured flush snapshot: book=\(bookId), version=\(version), page=\(snapshotPage), completed=\(snapshotCompleted)"
      )
    } else if pendingPageUpdates[bookId] != nil {
      logger.debug("♻️ [Progress/Page] Skip flush snapshot capture: pending update already exists")
    } else {
      logger.debug("⏭️ [Progress/Page] Skip flush snapshot capture: current page snapshot unavailable")
    }

    logger.debug(
      "🚿 [Progress/Page] Flush requested: book=\(bookId), hasPending=\(pendingPageUpdates[bookId] != nil), isSending=\(pageSendTasks[bookId] != nil)"
    )

    sendPendingPageProgress(for: bookId, trigger: "flush", priority: .userInitiated)
  }

  func submitEpubProgression(
    bookId: String,
    globalPageNumber: Int,
    progression: R2Progression,
    progressionData: Data?
  ) {
    let version = nextProgressVersion(for: bookId)
    let update = EpubUpdate(
      bookId: bookId,
      version: version,
      globalPageNumber: globalPageNumber,
      progression: progression,
      progressionData: progressionData
    )
    pendingEpubUpdates[bookId] = update

    logger.debug(
      "📝 [Progress/Epub] Queued update: book=\(bookId), version=\(version), href=\(progression.locator.href), globalPage=\(globalPageNumber), offline=\(AppConfig.isOffline)"
    )

    sendPendingEpubProgression(for: bookId, trigger: "enqueue")
  }

  func captureProgressCheckpoint(
    bookIds: Set<String>,
    waitForRecentFlush: Bool = false,
    flushGrace: Duration = .milliseconds(180)
  ) async -> ProgressCheckpoint {
    guard !bookIds.isEmpty else { return [:] }

    var checkpoint = buildCheckpoint(bookIds: bookIds)
    guard waitForRecentFlush else {
      logger.debug(
        "📍 [Progress/Checkpoint] Captured: \(checkpointSummary(checkpoint))"
      )
      return checkpoint
    }

    guard checkpoint.isEmpty, !hasPendingDispatchWork(for: bookIds) else {
      logger.debug(
        "📍 [Progress/Checkpoint] Captured after flush gate: \(checkpointSummary(checkpoint))"
      )
      return checkpoint
    }

    let pollInterval = Duration.milliseconds(30)
    var elapsed = Duration.zero
    while elapsed < flushGrace {
      try? await Task.sleep(for: pollInterval)
      elapsed += pollInterval
      checkpoint = buildCheckpoint(bookIds: bookIds)
      if !checkpoint.isEmpty || hasPendingDispatchWork(for: bookIds) {
        logger.debug(
          "📍 [Progress/Checkpoint] Captured after grace wait: \(checkpointSummary(checkpoint))"
        )
        return checkpoint
      }
    }

    logger.debug(
      "📍 [Progress/Checkpoint] Empty after grace wait: books=\(bookIds.count)"
    )
    return checkpoint
  }

  func waitUntilCheckpointReached(
    _ checkpoint: ProgressCheckpoint,
    timeout: Duration = .seconds(6)
  ) async -> Bool {
    guard !checkpoint.isEmpty else { return true }

    logger.debug(
      "⏳ [Progress/Checkpoint] Waiting: \(checkpointSummary(checkpoint)), timeout=\(timeout)"
    )

    if isCheckpointReached(checkpoint) {
      logger.debug(
        "✅ [Progress/Checkpoint] Already reached: \(checkpointSummary(checkpoint))"
      )
      return true
    }

    return await withTaskGroup(of: Bool.self) { group in
      group.addTask {
        await self.waitForCheckpoint(checkpoint)
        return true
      }
      group.addTask {
        try? await Task.sleep(for: timeout)
        return false
      }
      let result = await group.next() ?? false
      group.cancelAll()
      if !result {
        self.removeCheckpointWaiters(for: checkpoint)
        self.logger.warning(
          "⚠️ [Progress/Checkpoint] Wait timed out: \(self.checkpointSummary(checkpoint))"
        )
      } else {
        self.logger.debug(
          "✅ [Progress/Checkpoint] Reached: \(self.checkpointSummary(checkpoint))"
        )
      }
      return result
    }
  }

  func waitUntilSettled(bookIds: Set<String>, timeout: Duration = .seconds(6)) async -> Bool {
    let checkpoint = await captureProgressCheckpoint(
      bookIds: bookIds,
      waitForRecentFlush: true
    )
    return await waitUntilCheckpointReached(checkpoint, timeout: timeout)
  }

  private func waitForCheckpoint(_ checkpoint: ProgressCheckpoint) async {
    if isCheckpointReached(checkpoint) {
      return
    }
    await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
      checkpointWaiters.append(
        CheckpointWaiter(checkpoint: checkpoint, continuation: continuation)
      )
    }
  }

  private func removeCheckpointWaiters(for checkpoint: ProgressCheckpoint) {
    checkpointWaiters.removeAll { waiter in
      if waiter.checkpoint == checkpoint {
        waiter.continuation.resume()
        return true
      }
      return false
    }
  }

  /// Resume waiters whose required progress versions are now confirmed.
  private func notifyCheckpointWaiters() {
    checkpointWaiters.removeAll { waiter in
      if isCheckpointReached(waiter.checkpoint) {
        waiter.continuation.resume()
        return true
      }
      return false
    }
  }

  private func sendPendingPageProgress(
    for bookId: String,
    trigger: String,
    priority: TaskPriority = .userInitiated
  ) {
    guard pageSendTasks[bookId] == nil else {
      logger.debug(
        "⏳ [Progress/Page] Skip dispatch: in-flight request exists, book=\(bookId), trigger=\(trigger)"
      )
      return
    }

    guard pendingPageUpdates[bookId] != nil else {
      logger.debug(
        "⏭️ [Progress/Page] Skip dispatch: no pending update, book=\(bookId), trigger=\(trigger)"
      )
      return
    }

    let isFlush = trigger == "flush"
    pageSendTasks[bookId] = Task(priority: priority) { [weak self] in
      await self?.executePageSend(bookId: bookId, trigger: trigger, isFlush: isFlush)
    }
  }

  private func sendPendingEpubProgression(for bookId: String, trigger: String) {
    guard epubSendTasks[bookId] == nil else {
      logger.debug(
        "⏳ [Progress/Epub] Skip dispatch: in-flight request exists, book=\(bookId), trigger=\(trigger)"
      )
      return
    }

    guard pendingEpubUpdates[bookId] != nil else {
      logger.debug(
        "⏭️ [Progress/Epub] Skip dispatch: no pending update, book=\(bookId), trigger=\(trigger)"
      )
      return
    }

    epubSendTasks[bookId] = Task(priority: .userInitiated) { [weak self] in
      await self?.executeEpubSend(bookId: bookId, trigger: trigger)
    }
  }

  private func hasPendingDispatchWork(for bookIds: Set<String>) -> Bool {
    for bookId in bookIds {
      if pendingPageUpdates[bookId] != nil { return true }
      if pageSendTasks[bookId] != nil { return true }
      if pendingEpubUpdates[bookId] != nil { return true }
      if epubSendTasks[bookId] != nil { return true }
    }
    return false
  }

  private func nextProgressVersion(for bookId: String) -> UInt64 {
    let nextVersion = (progressVersionSeedByBook[bookId] ?? 0) + 1
    progressVersionSeedByBook[bookId] = nextVersion
    latestSubmittedProgressVersionByBook[bookId] = nextVersion
    return nextVersion
  }

  private func buildCheckpoint(bookIds: Set<String>) -> ProgressCheckpoint {
    var checkpoint: ProgressCheckpoint = [:]
    for bookId in bookIds {
      let version = latestSubmittedProgressVersionByBook[bookId] ?? 0
      if version > 0 {
        checkpoint[bookId] = version
      }
    }
    return checkpoint
  }

  private func markProgressSettled(
    bookId: String,
    version: UInt64,
    serverSynced: Bool
  ) {
    let previousSettled = latestSettledProgressVersionByBook[bookId] ?? 0
    if version > previousSettled {
      latestSettledProgressVersionByBook[bookId] = version
    }

    guard serverSynced else { return }
    let previousServerSynced = latestServerSyncedProgressVersionByBook[bookId] ?? 0
    if version > previousServerSynced {
      latestServerSyncedProgressVersionByBook[bookId] = version
    }

    logger.debug(
      "✅ [Progress/Checkpoint] Settled version: book=\(bookId), version=\(version), serverSynced=\(serverSynced)"
    )
  }

  private func isCheckpointReached(_ checkpoint: ProgressCheckpoint) -> Bool {
    for (bookId, requiredVersion) in checkpoint {
      let confirmedVersion: UInt64
      if AppConfig.isOffline {
        confirmedVersion = latestSettledProgressVersionByBook[bookId] ?? 0
      } else {
        confirmedVersion = latestServerSyncedProgressVersionByBook[bookId] ?? 0
      }

      if confirmedVersion < requiredVersion {
        return false
      }
    }
    return true
  }

  private func checkpointSummary(_ checkpoint: ProgressCheckpoint) -> String {
    guard !checkpoint.isEmpty else { return "entries=0" }

    let sortedEntries = checkpoint.sorted(by: { $0.key < $1.key })
    let sample = sortedEntries.prefix(3).map { "\($0.key)=v\($0.value)" }.joined(separator: ", ")
    let suffix = checkpoint.count > 3 ? ", ..." : ""
    return "entries=\(checkpoint.count), sample=[\(sample)\(suffix)]"
  }

  private func scheduleLocalPageProgressCacheUpdate(_ update: PageUpdate) {
    localPageCacheTokenSeed += 1
    let token = localPageCacheTokenSeed
    localPageCacheTokens[update.bookId] = token

    Task(priority: .utility) { [weak self] in
      await self?.applyLocalPageProgressCacheUpdate(update, token: token)
    }
  }

  private func applyLocalPageProgressCacheUpdate(_ update: PageUpdate, token: UInt64) async {
    guard localPageCacheTokens[update.bookId] == token else { return }

    await DatabaseOperator.shared.updateReadingProgress(
      bookId: update.bookId,
      page: update.page,
      completed: update.completed
    )

    guard localPageCacheTokens[update.bookId] == token else { return }
    localPageCacheTokens.removeValue(forKey: update.bookId)
    logger.debug(
      "💾 [Progress/Page] Updated local cache: book=\(update.bookId), version=\(update.version), page=\(update.page), completed=\(update.completed)"
    )
  }

  private func executePageSend(bookId: String, trigger: String, isFlush: Bool) async {
    guard let update = pendingPageUpdates.removeValue(forKey: bookId) else {
      pageSendTasks.removeValue(forKey: bookId)
      notifyCheckpointWaiters()
      return
    }

    logger.debug(
      "📤 [Progress/Page] Dispatching update: book=\(bookId), version=\(update.version), page=\(update.page), completed=\(update.completed), trigger=\(trigger)"
    )

    let result = await performPageProgressUpdateWithTimeoutHandling(update, isFlush: isFlush)
    switch result {
    case .serverUpdated:
      markProgressSettled(bookId: update.bookId, version: update.version, serverSynced: true)
      scheduleLocalPageProgressCacheUpdate(update)
    case .offlineQueued:
      markProgressSettled(bookId: update.bookId, version: update.version, serverSynced: false)
    case .skipped, .failed:
      break
    }

    pageSendTasks.removeValue(forKey: bookId)
    notifyCheckpointWaiters()

    if pendingPageUpdates[bookId] != nil {
      logger.debug("🔁 [Progress/Page] Dispatching next queued update: book=\(bookId)")
      sendPendingPageProgress(for: bookId, trigger: "drain")
    }
  }

  private func executeEpubSend(bookId: String, trigger: String) async {
    guard let update = pendingEpubUpdates.removeValue(forKey: bookId) else {
      epubSendTasks.removeValue(forKey: bookId)
      notifyCheckpointWaiters()
      return
    }

    logger.debug(
      "📤 [Progress/Epub] Dispatching update: book=\(bookId), version=\(update.version), href=\(update.progression.locator.href), globalPage=\(update.globalPageNumber), trigger=\(trigger)"
    )

    let result = await performEpubProgressionUpdateWithTimeoutHandling(update)
    switch result {
    case .serverUpdated:
      markProgressSettled(bookId: update.bookId, version: update.version, serverSynced: true)
    case .offlineQueued:
      markProgressSettled(bookId: update.bookId, version: update.version, serverSynced: false)
    case .skipped, .failed:
      break
    }

    epubSendTasks.removeValue(forKey: bookId)
    notifyCheckpointWaiters()

    if pendingEpubUpdates[bookId] != nil {
      logger.debug("🔁 [Progress/Epub] Dispatching next queued update: book=\(bookId)")
      sendPendingEpubProgression(for: bookId, trigger: "drain")
    }
  }

  private func performPageProgressUpdateWithTimeoutHandling(
    _ update: PageUpdate,
    isFlush: Bool
  ) async -> ProgressUpdateResult {
    if AppConfig.isOffline {
      await Self.performPageProgressOfflineUpdate(update)
      return .offlineQueued
    }

    var timeoutRetryAttempt = 0
    while true {
      do {
        try await Self.performPageProgressServerUpdate(update, timeout: progressRequestTimeout)
        return .serverUpdated
      } catch {
        guard Self.isTimeoutError(error) else {
          logger.error(
            "❌ [Progress/Page] Update failed: book=\(update.bookId), version=\(update.version), page=\(update.page), error=\(error.localizedDescription)"
          )
          return .failed
        }

        if pendingPageUpdates[update.bookId] != nil {
          logger.warning(
            "⏭️ [Progress/Page] Timeout and skipped outdated update: book=\(update.bookId), version=\(update.version), page=\(update.page)"
          )
          return .skipped
        }

        guard timeoutRetryAttempt < timeoutRetryLimit else {
          logger.error(
            "❌ [Progress/Page] Timeout retries exhausted: book=\(update.bookId), version=\(update.version), page=\(update.page), retries=\(timeoutRetryLimit)"
          )
          if isFlush {
            await MainActor.run {
              ErrorManager.shared.notify(
                message: String(localized: "notification.progressSyncFailed")
              )
            }
          }
          return .failed
        }

        timeoutRetryAttempt += 1
        logger.warning(
          "⏱️ [Progress/Page] Timeout, retrying: book=\(update.bookId), version=\(update.version), page=\(update.page), attempt=\(timeoutRetryAttempt)/\(timeoutRetryLimit)"
        )
      }
    }
  }

  private func performEpubProgressionUpdateWithTimeoutHandling(
    _ update: EpubUpdate
  ) async -> ProgressUpdateResult {
    var timeoutRetryAttempt = 0

    while true {
      do {
        try await Self.performEpubProgressionUpdate(
          update,
          timeout: progressRequestTimeout
        )
        if AppConfig.isOffline {
          return .offlineQueued
        }
        return .serverUpdated
      } catch {
        guard Self.isTimeoutError(error) else {
          logger.error(
            "❌ [Progress/Epub] Update failed: book=\(update.bookId), version=\(update.version), error=\(error.localizedDescription)"
          )
          return .failed
        }

        if pendingEpubUpdates[update.bookId] != nil {
          logger.warning(
            "⏭️ [Progress/Epub] Timeout and skipped outdated update: book=\(update.bookId), version=\(update.version)"
          )
          return .skipped
        }

        guard timeoutRetryAttempt < timeoutRetryLimit else {
          logger.error(
            "❌ [Progress/Epub] Timeout retries exhausted: book=\(update.bookId), version=\(update.version), retries=\(timeoutRetryLimit)"
          )
          return .failed
        }

        timeoutRetryAttempt += 1
        logger.warning(
          "⏱️ [Progress/Epub] Timeout, retrying: book=\(update.bookId), version=\(update.version), attempt=\(timeoutRetryAttempt)/\(timeoutRetryLimit)"
        )
      }
    }
  }

  private nonisolated static func performPageProgressOfflineUpdate(_ update: PageUpdate) async {
    let logger = AppLogger(.reader)

    logger.debug(
      "📨 [Progress/Page] Queue offline update: book=\(update.bookId), version=\(update.version), page=\(update.page), completed=\(update.completed)"
    )

    await DatabaseOperator.shared.queuePendingProgress(
      instanceId: AppConfig.current.instanceId,
      bookId: update.bookId,
      page: update.page,
      completed: update.completed,
      progressionData: nil
    )
    await DatabaseOperator.shared.updateReadingProgress(
      bookId: update.bookId,
      page: update.page,
      completed: update.completed
    )
    await DatabaseOperator.shared.commit()
    logger.debug(
      "💾 [Progress/Page] Queued offline sync item: book=\(update.bookId), version=\(update.version), page=\(update.page), completed=\(update.completed)"
    )
  }

  private nonisolated static func performPageProgressServerUpdate(
    _ update: PageUpdate,
    timeout: TimeInterval
  ) async throws {
    let logger = AppLogger(.reader)

    logger.debug(
      "📨 [Progress/Page] Start server sync: book=\(update.bookId), version=\(update.version), page=\(update.page), completed=\(update.completed), timeout=\(timeout)s"
    )

    try await withHardTimeout(seconds: timeout) {
      try await BookService.shared.updatePageReadProgress(
        bookId: update.bookId,
        page: update.page,
        completed: update.completed,
        timeout: timeout
      )
    }

    logger.debug(
      "✅ [Progress/Page] Server sync completed: book=\(update.bookId), version=\(update.version), page=\(update.page), completed=\(update.completed)"
    )
  }

  private nonisolated static func performEpubProgressionUpdate(
    _ update: EpubUpdate,
    timeout: TimeInterval
  ) async throws {
    let logger = AppLogger(.reader)

    do {
      let totalProgression = update.progression.locator.locations?.totalProgression.map(Double.init)
      let fallbackPage = max(0, update.globalPageNumber - 1)

      if AppConfig.isOffline {
        _ = await DatabaseOperator.shared.updateEpubReadingProgressFromTotalProgression(
          bookId: update.bookId,
          totalProgression: totalProgression,
          fallbackPage: fallbackPage
        )
        logger.debug(
          "💾 [Progress/Epub] Queue offline update: book=\(update.bookId), version=\(update.version), globalPage=\(update.globalPageNumber), totalProgression=\(totalProgression ?? 0)"
        )
        await DatabaseOperator.shared.queuePendingProgress(
          instanceId: AppConfig.current.instanceId,
          bookId: update.bookId,
          page: update.globalPageNumber,
          completed: false,
          progressionData: update.progressionData
        )
        logger.debug(
          "✅ [Progress/Epub] Queued offline sync item: book=\(update.bookId), version=\(update.version), globalPage=\(update.globalPageNumber)"
        )
      } else {
        logger.debug(
          "📨 [Progress/Epub] Start server sync: book=\(update.bookId), version=\(update.version), href=\(update.progression.locator.href), globalPage=\(update.globalPageNumber), timeout=\(timeout)s"
        )
        try await withHardTimeout(seconds: timeout) {
          try await BookService.shared.updateWebPubProgression(
            bookId: update.bookId,
            progression: update.progression,
            timeout: timeout
          )
        }
        logger.debug(
          "✅ [Progress/Epub] Server sync completed: book=\(update.bookId), version=\(update.version), href=\(update.progression.locator.href), globalPage=\(update.globalPageNumber)"
        )
        _ = await DatabaseOperator.shared.updateEpubReadingProgressFromTotalProgression(
          bookId: update.bookId,
          totalProgression: totalProgression,
          fallbackPage: fallbackPage
        )
      }

      await DatabaseOperator.shared.updateBookEpubProgression(
        bookId: update.bookId,
        progression: update.progression
      )
      await DatabaseOperator.shared.commit()
    } catch let apiError as APIError {
      if case .badRequest(let message, _, _, _) = apiError,
        message.lowercased().contains("epub extension not found")
      {
        logger.error(
          "❌ [Progress/Epub] EPUB extension not found: book=\(update.bookId), version=\(update.version)"
        )
        await MainActor.run {
          ErrorManager.shared.alert(
            error: AppErrorType.operationFailed(
              message: String(
                localized: "error.epubExtensionNotFound",
                defaultValue: "Failed to sync reading progress. This book may need to be re-analyzed on the server."
              )
            )
          )
        }
      }
      throw apiError
    } catch {
      throw error
    }
  }

  /// Enforce a hard deadline by racing the operation against a sleep timer.
  /// URLRequest.timeoutInterval only controls idle timeout (time between data packets),
  /// not total request duration. This ensures requests are cancelled after the deadline.
  private nonisolated static func withHardTimeout(
    seconds: TimeInterval,
    operation: @Sendable @escaping () async throws -> Void
  ) async throws {
    try await withThrowingTaskGroup(of: Void.self) { group in
      group.addTask {
        try await operation()
      }

      group.addTask {
        try await Task.sleep(for: .seconds(seconds))
        throw URLError(.timedOut)
      }

      guard let firstCompleted = try await group.next() else {
        throw URLError(.unknown)
      }
      _ = firstCompleted
      group.cancelAll()
    }
  }

  private nonisolated static func isTimeoutError(_ error: Error) -> Bool {
    if let apiError = error as? APIError {
      switch apiError {
      case .networkError(let wrappedError, _):
        return isTimeoutError(wrappedError)
      default:
        return false
      }
    }

    if let appError = error as? AppErrorType {
      if case .networkTimeout = appError {
        return true
      }
      return false
    }

    let nsError = error as NSError
    return nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorTimedOut
  }

}
