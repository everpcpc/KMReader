//
//  ReaderProgressDispatchService.swift
//  KMReader
//

import Foundation

actor ReaderProgressDispatchService {
  static let shared = ReaderProgressDispatchService()

  private struct PageUpdate: Sendable {
    let bookId: String
    let page: Int
    let completed: Bool
  }

  private struct EpubUpdate: Sendable {
    let bookId: String
    let globalPageNumber: Int
    let progression: R2Progression
    let progressionData: Data?
  }

  private enum PageProgressUpdateResult {
    case serverUpdated
    case offlineQueued
    case skipped
    case failed
  }

  private let logger = AppLogger(.reader)
  private let progressRequestTimeout: TimeInterval = 3
  private let timeoutRetryLimit = 2

  private var pendingPageUpdates: [String: PageUpdate] = [:]
  private var pageSendTasks: [String: Task<Void, Never>] = [:]
  private var localPageCacheTokenSeed: UInt64 = 0
  private var localPageCacheTokens: [String: UInt64] = [:]

  private var pendingEpubUpdates: [String: EpubUpdate] = [:]
  private var epubSendTasks: [String: Task<Void, Never>] = [:]

  /// Continuations waiting for specific book IDs to settle
  private var settleWaiters: [(bookIds: Set<String>, continuation: CheckedContinuation<Void, Never>)] = []

  private init() {}

  func submitPageProgress(bookId: String, page: Int, completed: Bool) {
    let update = PageUpdate(bookId: bookId, page: page, completed: completed)
    pendingPageUpdates[bookId] = update
    logger.debug(
      "📝 Queued page progress dispatch for book \(bookId): page=\(page), completed=\(completed)"
    )

    sendPendingPageProgress(for: bookId, trigger: "enqueue")
  }

  func flushPageProgress(bookId: String, snapshotPage: Int?, snapshotCompleted: Bool?) {
    guard !bookId.isEmpty else {
      logger.warning("⚠️ Skip page progress flush because book ID is empty")
      return
    }

    if pendingPageUpdates[bookId] == nil,
      let snapshotPage,
      let snapshotCompleted
    {
      let snapshot = PageUpdate(bookId: bookId, page: snapshotPage, completed: snapshotCompleted)
      pendingPageUpdates[bookId] = snapshot
      logger.debug(
        "🧲 Force-captured current page progress before flush for book \(bookId): page=\(snapshotPage), completed=\(snapshotCompleted)"
      )
    } else if pendingPageUpdates[bookId] != nil {
      logger.debug("♻️ Skip force-capture progress during flush because pending progress already exists")
    } else {
      logger.debug("⏭️ Skip force-capture progress during flush because current page snapshot is unavailable")
    }

    logger.debug(
      "🚿 Flush page progress requested for book \(bookId): hasPending=\(pendingPageUpdates[bookId] != nil), isSending=\(pageSendTasks[bookId] != nil)"
    )

    sendPendingPageProgress(for: bookId, trigger: "flush", priority: .userInitiated)
  }

  func submitEpubProgression(
    bookId: String,
    globalPageNumber: Int,
    progression: R2Progression,
    progressionData: Data?
  ) {
    let update = EpubUpdate(
      bookId: bookId,
      globalPageNumber: globalPageNumber,
      progression: progression,
      progressionData: progressionData
    )
    pendingEpubUpdates[bookId] = update

    logger.debug(
      "📝 Queued EPUB progression dispatch for book \(bookId): href=\(progression.locator.href), globalPage=\(globalPageNumber), offline=\(AppConfig.isOffline)"
    )

    sendPendingEpubProgression(for: bookId, trigger: "enqueue")
  }

  func waitUntilSettled(bookIds: Set<String>, timeout: Duration = .seconds(6)) async -> Bool {
    guard !bookIds.isEmpty else { return true }

    if !hasPendingDispatchWork(for: bookIds) {
      return true
    }

    return await withTaskGroup(of: Bool.self) { group in
      group.addTask {
        await self.waitForSettle(bookIds: bookIds)
        return true
      }
      group.addTask {
        try? await Task.sleep(for: timeout)
        return false
      }
      let result = await group.next() ?? false
      group.cancelAll()
      if !result {
        self.removeSettleWaiters(for: bookIds)
      }
      return result
    }
  }

  private func waitForSettle(bookIds: Set<String>) async {
    if !hasPendingDispatchWork(for: bookIds) {
      return
    }
    await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
      settleWaiters.append((bookIds: bookIds, continuation: continuation))
    }
  }

  private func removeSettleWaiters(for bookIds: Set<String>) {
    settleWaiters.removeAll { waiter in
      if waiter.bookIds == bookIds {
        waiter.continuation.resume()
        return true
      }
      return false
    }
  }

  /// Check and resume any waiters whose book IDs are now fully settled
  private func notifySettledWaiters() {
    settleWaiters.removeAll { waiter in
      if !hasPendingDispatchWork(for: waiter.bookIds) {
        waiter.continuation.resume()
        return true
      }
      return false
    }
  }

  private func sendPendingPageProgress(
    for bookId: String,
    trigger: String,
    priority: TaskPriority = .utility
  ) {
    guard pageSendTasks[bookId] == nil else {
      logger.debug("⏳ Page progress send already in flight for book \(bookId), trigger=\(trigger)")
      return
    }

    guard pendingPageUpdates[bookId] != nil else {
      logger.debug("⏭️ No pending page progress to dispatch for book \(bookId), trigger=\(trigger)")
      return
    }

    let isFlush = trigger == "flush"
    pageSendTasks[bookId] = Task(priority: priority) { [weak self] in
      await self?.executePageSend(bookId: bookId, trigger: trigger, isFlush: isFlush)
    }
  }

  private func sendPendingEpubProgression(for bookId: String, trigger: String) {
    guard epubSendTasks[bookId] == nil else {
      logger.debug("⏳ EPUB progression send already in flight for book \(bookId), trigger=\(trigger)")
      return
    }

    guard pendingEpubUpdates[bookId] != nil else {
      logger.debug("⏭️ No pending EPUB progression to dispatch for book \(bookId), trigger=\(trigger)")
      return
    }

    epubSendTasks[bookId] = Task(priority: .utility) { [weak self] in
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
      "💾 Cached page progress locally for book \(update.bookId): page=\(update.page), completed=\(update.completed)"
    )
  }

  private func executePageSend(bookId: String, trigger: String, isFlush: Bool) async {
    guard let update = pendingPageUpdates.removeValue(forKey: bookId) else {
      pageSendTasks.removeValue(forKey: bookId)
      notifySettledWaiters()
      return
    }

    logger.debug(
      "📤 Dispatching page progress for book \(bookId): page=\(update.page), completed=\(update.completed), trigger=\(trigger)"
    )

    let result = await performPageProgressUpdateWithTimeoutHandling(update, isFlush: isFlush)
    if case .serverUpdated = result {
      scheduleLocalPageProgressCacheUpdate(update)
    }

    pageSendTasks.removeValue(forKey: bookId)

    if pendingPageUpdates[bookId] != nil {
      logger.debug("🔁 Dispatching next queued page progress for book \(bookId)")
      sendPendingPageProgress(for: bookId, trigger: "drain")
    } else {
      notifySettledWaiters()
    }
  }

  private func executeEpubSend(bookId: String, trigger: String) async {
    guard let update = pendingEpubUpdates.removeValue(forKey: bookId) else {
      epubSendTasks.removeValue(forKey: bookId)
      notifySettledWaiters()
      return
    }

    logger.debug(
      "📤 Dispatching EPUB progression for book \(bookId): href=\(update.progression.locator.href), globalPage=\(update.globalPageNumber), trigger=\(trigger)"
    )

    await performEpubProgressionUpdateWithTimeoutHandling(update)

    epubSendTasks.removeValue(forKey: bookId)

    if pendingEpubUpdates[bookId] != nil {
      logger.debug("🔁 Dispatching next queued EPUB progression for book \(bookId)")
      sendPendingEpubProgression(for: bookId, trigger: "drain")
    } else {
      notifySettledWaiters()
    }
  }

  private func performPageProgressUpdateWithTimeoutHandling(
    _ update: PageUpdate,
    isFlush: Bool
  ) async -> PageProgressUpdateResult {
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
            "Failed to update page progress for book \(update.bookId) page \(update.page): \(error.localizedDescription)"
          )
          return .failed
        }

        if pendingPageUpdates[update.bookId] != nil {
          logger.warning(
            "⏭️ Timed out page progress for book \(update.bookId) page \(update.page), newer progress exists so skipping current update"
          )
          return .skipped
        }

        guard timeoutRetryAttempt < timeoutRetryLimit else {
          logger.error(
            "❌ Timed out page progress for book \(update.bookId) page \(update.page) after \(timeoutRetryLimit) retries"
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
          "⏱️ Timed out page progress for book \(update.bookId) page \(update.page), retrying (\(timeoutRetryAttempt)/\(timeoutRetryLimit))"
        )
      }
    }
  }

  private func performEpubProgressionUpdateWithTimeoutHandling(_ update: EpubUpdate) async {
    var timeoutRetryAttempt = 0

    while true {
      do {
        try await Self.performEpubProgressionUpdate(
          update,
          timeout: progressRequestTimeout
        )
        return
      } catch {
        guard Self.isTimeoutError(error) else {
          logger.error("Failed to update progression: \(error.localizedDescription)")
          return
        }

        if pendingEpubUpdates[update.bookId] != nil {
          logger.warning(
            "⏭️ Timed out EPUB progression for book \(update.bookId), newer progress exists so skipping current update"
          )
          return
        }

        guard timeoutRetryAttempt < timeoutRetryLimit else {
          logger.error(
            "❌ Timed out EPUB progression for book \(update.bookId) after \(timeoutRetryLimit) retries"
          )
          return
        }

        timeoutRetryAttempt += 1
        logger.warning(
          "⏱️ Timed out EPUB progression for book \(update.bookId), retrying (\(timeoutRetryAttempt)/\(timeoutRetryLimit))"
        )
      }
    }
  }

  private nonisolated static func performPageProgressOfflineUpdate(_ update: PageUpdate) async {
    let logger = AppLogger(.reader)

    logger.debug(
      "📨 Performing page progress update for book \(update.bookId): page=\(update.page), completed=\(update.completed), offline=\(AppConfig.isOffline)"
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
      "💾 Queued page progress for offline sync: book=\(update.bookId), page=\(update.page), completed=\(update.completed)"
    )
  }

  private nonisolated static func performPageProgressServerUpdate(
    _ update: PageUpdate,
    timeout: TimeInterval
  ) async throws {
    let logger = AppLogger(.reader)

    logger.debug(
      "📨 Performing page progress update for book \(update.bookId): page=\(update.page), completed=\(update.completed), offline=\(AppConfig.isOffline)"
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
      "✅ Page progress update completed for book \(update.bookId): page=\(update.page), completed=\(update.completed)"
    )
  }

  private nonisolated static func performEpubProgressionUpdate(
    _ update: EpubUpdate,
    timeout: TimeInterval
  ) async throws {
    let logger = AppLogger(.reader)

    do {
      if AppConfig.isOffline {
        logger.debug(
          "💾 Queue EPUB progression for offline sync: book=\(update.bookId), globalPage=\(update.globalPageNumber)"
        )
        await DatabaseOperator.shared.queuePendingProgress(
          instanceId: AppConfig.current.instanceId,
          bookId: update.bookId,
          page: update.globalPageNumber,
          completed: false,
          progressionData: update.progressionData
        )
        logger.debug(
          "✅ Queued EPUB progression for offline sync: book=\(update.bookId), globalPage=\(update.globalPageNumber)"
        )
      } else {
        logger.debug(
          "📤 Sending EPUB progression request for book=\(update.bookId), href=\(update.progression.locator.href), globalPage=\(update.globalPageNumber)"
        )
        try await withHardTimeout(seconds: timeout) {
          try await BookService.shared.updateWebPubProgression(
            bookId: update.bookId,
            progression: update.progression,
            timeout: timeout
          )
        }
        logger.debug(
          "✅ EPUB progression request completed for book=\(update.bookId), href=\(update.progression.locator.href), globalPage=\(update.globalPageNumber)"
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
        logger.error("Failed to update progression: EPUB extension not found")
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
      // Wait for the first task to complete; if timeout fires first, it throws
      try await group.next()
      // Cancel whichever task is still running
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
