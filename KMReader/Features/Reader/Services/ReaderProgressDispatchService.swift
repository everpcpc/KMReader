//
//  ReaderProgressDispatchService.swift
//  KMReader
//

import Foundation

actor ReaderProgressDispatchService {
  static let shared = ReaderProgressDispatchService()

  private struct PageUpdate {
    let bookId: String
    let page: Int
    let completed: Bool
  }

  private struct EpubUpdate {
    let bookId: String
    let globalPageNumber: Int
    let progression: R2Progression
    let progressionData: Data?
  }

  private let logger = AppLogger(.reader)

  private var pendingPageUpdates: [String: PageUpdate] = [:]
  private var pageDebounceTasks: [String: Task<Void, Never>] = [:]
  private var pageSendTasks: [String: Task<Void, Never>] = [:]

  private var pendingEpubUpdates: [String: EpubUpdate] = [:]
  private var epubSendTasks: [String: Task<Void, Never>] = [:]

  private init() {}

  func submitPageProgress(bookId: String, page: Int, completed: Bool, debounceSeconds: Int) {
    let update = PageUpdate(bookId: bookId, page: page, completed: completed)
    pendingPageUpdates[bookId] = update
    logger.debug(
      "📝 Queued page progress dispatch for book \(bookId): page=\(page), completed=\(completed), debounce=\(debounceSeconds)s"
    )

    pageDebounceTasks[bookId]?.cancel()
    pageDebounceTasks[bookId] = Task(priority: .utility) { [weak self] in
      do {
        try await Task.sleep(for: .seconds(debounceSeconds))
      } catch {
        return
      }
      await self?.triggerDebouncedPageSend(bookId: bookId)
    }
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

    pageDebounceTasks[bookId]?.cancel()
    pageDebounceTasks.removeValue(forKey: bookId)

    logger.debug(
      "🚿 Flush page progress requested for book \(bookId): hasPending=\(pendingPageUpdates[bookId] != nil), isSending=\(pageSendTasks[bookId] != nil)"
    )

    sendPendingPageProgress(for: bookId, trigger: "flush")
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

  private func triggerDebouncedPageSend(bookId: String) {
    pageDebounceTasks.removeValue(forKey: bookId)
    sendPendingPageProgress(for: bookId, trigger: "debounce")
  }

  private func sendPendingPageProgress(for bookId: String, trigger: String) {
    guard pageSendTasks[bookId] == nil else {
      logger.debug("⏳ Page progress send already in flight for book \(bookId), trigger=\(trigger)")
      return
    }

    guard pendingPageUpdates[bookId] != nil else {
      logger.debug("⏭️ No pending page progress to dispatch for book \(bookId), trigger=\(trigger)")
      return
    }

    pageSendTasks[bookId] = Task(priority: .utility) { [weak self] in
      await self?.executePageSend(bookId: bookId, trigger: trigger)
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

  private func executePageSend(bookId: String, trigger: String) async {
    guard let update = pendingPageUpdates.removeValue(forKey: bookId) else {
      pageSendTasks.removeValue(forKey: bookId)
      return
    }

    logger.debug(
      "📤 Dispatching page progress for book \(bookId): page=\(update.page), completed=\(update.completed), trigger=\(trigger)"
    )

    await ReaderProgressTracker.shared.begin(bookId: bookId)
    await Self.performPageProgressUpdate(update)
    await ReaderProgressTracker.shared.end(bookId: bookId)

    pageSendTasks.removeValue(forKey: bookId)

    if pendingPageUpdates[bookId] != nil, pageDebounceTasks[bookId] == nil {
      logger.debug("🔁 Dispatching next queued page progress for book \(bookId)")
      sendPendingPageProgress(for: bookId, trigger: "drain")
    }
  }

  private func executeEpubSend(bookId: String, trigger: String) async {
    guard let update = pendingEpubUpdates.removeValue(forKey: bookId) else {
      epubSendTasks.removeValue(forKey: bookId)
      return
    }

    logger.debug(
      "📤 Dispatching EPUB progression for book \(bookId): href=\(update.progression.locator.href), globalPage=\(update.globalPageNumber), trigger=\(trigger)"
    )

    await ReaderProgressTracker.shared.begin(bookId: bookId)
    await Self.performEpubProgressionUpdate(update)
    await ReaderProgressTracker.shared.end(bookId: bookId)

    epubSendTasks.removeValue(forKey: bookId)

    if pendingEpubUpdates[bookId] != nil {
      logger.debug("🔁 Dispatching next queued EPUB progression for book \(bookId)")
      sendPendingEpubProgression(for: bookId, trigger: "drain")
    }
  }

  private nonisolated static func performPageProgressUpdate(_ update: PageUpdate) async {
    let logger = AppLogger(.reader)

    logger.debug(
      "📨 Performing page progress update for book \(update.bookId): page=\(update.page), completed=\(update.completed), offline=\(AppConfig.isOffline)"
    )

    do {
      if AppConfig.isOffline {
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
      } else {
        try await BookService.shared.updatePageReadProgress(
          bookId: update.bookId,
          page: update.page,
          completed: update.completed
        )
        await DatabaseOperator.shared.updateReadingProgress(
          bookId: update.bookId,
          page: update.page,
          completed: update.completed
        )
        logger.debug(
          "✅ Page progress update completed for book \(update.bookId): page=\(update.page), completed=\(update.completed)"
        )
      }
    } catch {
      logger.error(
        "Failed to update page progress for book \(update.bookId) page \(update.page): \(error.localizedDescription)"
      )
    }
  }

  private nonisolated static func performEpubProgressionUpdate(_ update: EpubUpdate) async {
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
        await DatabaseOperator.shared.commit()
        logger.debug(
          "✅ Queued EPUB progression for offline sync: book=\(update.bookId), globalPage=\(update.globalPageNumber)"
        )
      } else {
        logger.debug(
          "📤 Sending EPUB progression request for book=\(update.bookId), href=\(update.progression.locator.href), globalPage=\(update.globalPageNumber)"
        )
        try await BookService.shared.updateWebPubProgression(
          bookId: update.bookId,
          progression: update.progression
        )
        logger.debug(
          "✅ EPUB progression request completed for book=\(update.bookId), href=\(update.progression.locator.href), globalPage=\(update.globalPageNumber)"
        )
      }
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
      } else {
        logger.error("Failed to update progression: \(apiError.localizedDescription)")
      }
    } catch {
      logger.error("Failed to update progression: \(error.localizedDescription)")
    }
  }
}
