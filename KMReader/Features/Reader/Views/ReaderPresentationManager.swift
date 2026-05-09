//
// ReaderPresentationManager.swift
//
//

import Foundation
import Observation

#if os(iOS)
  import UIKit
#endif

@MainActor
@Observable
final class ReaderPresentationManager {
  typealias FlushHandler = @MainActor () -> Void

  private(set) var currentSession: ReaderSession?
  private let logger = AppLogger(.reader)
  private var flushHandlers: [UUID: FlushHandler] = [:]

  #if os(iOS)
    private var backgroundFlushTaskID: UIBackgroundTaskIdentifier = .invalid
    private var backgroundFlushAwaitTask: Task<Void, Never>?
  #endif

  var handoffTitle: String {
    currentSession?.handoffTitle ?? ""
  }

  var handoffURL: URL? {
    currentSession?.handoffURL
  }

  var sourceBookId: String? {
    currentSession?.sourceBookId
  }

  private(set) var readerCommandState = ReaderCommandState()
  private var readerCommandHandlers: ReaderCommandHandlers?

  #if os(macOS)
    private var openWindowHandler: (() -> Void)?
    private var isReaderWindowVisible = false
  #endif

  func present(
    book: Book,
    incognito: Bool,
    readListContext: ReaderReadListContext? = nil
  ) {
    #if os(macOS)
      if let currentSession {
        finishSession(currentSession, syncVisited: true)
        clearReaderCommands()
      }
    #else
      if currentSession != nil {
        closeReader(syncVisited: false)
      }
    #endif

    let session = ReaderSession(
      book: book,
      incognito: incognito,
      readListContext: readListContext
    )
    currentSession = session

    #if os(iOS)
      ReaderLiveActivityManager.shared.readerDidOpen(book: book, incognito: incognito)
    #endif

    #if os(macOS)
      guard let openWindowHandler else {
        logger.error("Reader window opener not configured")
        currentSession = nil
        return
      }

      if !isReaderWindowVisible {
        openWindowHandler()
      }
    #endif
  }

  func registerFlushHandler(for sessionID: UUID, handler: @escaping FlushHandler) {
    guard currentSession?.id == sessionID else { return }
    flushHandlers[sessionID] = handler
  }

  func clearFlushHandler(for sessionID: UUID) {
    flushHandlers.removeValue(forKey: sessionID)
  }

  #if os(iOS)
    /// Flush in-flight read progress when the app backgrounds, requesting iOS background
    /// time so the URLSession PATCH can finish before the process is suspended. Without
    /// this, in-flight progress writes can be cancelled by iOS suspension and the user
    /// loses the trailing pages of their reading session.
    func flushForBackgrounding() {
      guard let session = currentSession else { return }
      guard !session.incognito else { return }
      guard let flushHandler = flushHandlers[session.id] else { return }

      // Drain any previous in-flight background flush before starting a fresh one.
      // Without this, a rapid background → foreground → switch-book → background
      // sequence within the 20s checkpoint window of the previous flush would skip
      // flushing the new session entirely (the old `backgroundFlushTaskID` is still
      // valid until its awaiter resolves), risking lost trailing pages on the new
      // session's suspension. iOS keeps the app alive while any UIBackgroundTask is
      // active, so ending the previous one and starting a fresh one is safe — the
      // newly-requested task carries the new session through suspension.
      endBackgroundFlushTask()

      backgroundFlushTaskID = UIApplication.shared.beginBackgroundTask(
        withName: "ReaderProgressFlush"
      ) { [weak self] in
        // iOS expiration handler: end the task immediately to avoid termination.
        // Any in-flight URLSession beyond this point is on its own; we cannot block.
        self?.endBackgroundFlushTask()
      }

      // Submit the flush regardless of whether iOS granted background time. In the
      // worst case (no time granted) the PATCH still has whatever foreground time
      // remains; that's strictly better than not flushing at all.
      flushHandler()

      // If no background time was granted, there is nothing more we can do — the
      // PATCH is best-effort under the remaining foreground window.
      guard backgroundFlushTaskID != .invalid else { return }

      logger.debug("📦 [Progress/Backgrounding] Started background flush task")

      // Await the dispatcher's checkpoint so the URLSession PATCH actually settles
      // before we release the iOS background time. Bounded by 20s to leave headroom
      // under the typical ~30s iOS background window.
      let bookIds = session.visitedBookIds.union([session.book.id])
      backgroundFlushAwaitTask = Task { [weak self] in
        let checkpoint = await ReaderProgressDispatchService.shared.captureProgressCheckpoint(
          bookIds: bookIds,
          waitForRecentFlush: true
        )
        let settled = await ReaderProgressDispatchService.shared.waitUntilCheckpointReached(
          checkpoint,
          timeout: .seconds(20)
        )
        await MainActor.run {
          self?.logger.debug(
            "📦 [Progress/Backgrounding] Background flush \(settled ? "settled" : "timed out"); ending task"
          )
          self?.endBackgroundFlushTask()
        }
      }
    }

    private func endBackgroundFlushTask() {
      backgroundFlushAwaitTask?.cancel()
      backgroundFlushAwaitTask = nil
      guard backgroundFlushTaskID != .invalid else { return }
      UIApplication.shared.endBackgroundTask(backgroundFlushTaskID)
      backgroundFlushTaskID = .invalid
    }
  #endif

  func trackVisitedBook(sessionID: UUID, bookId: String, seriesId: String?) {
    guard var session = currentSession, session.id == sessionID else { return }
    session.visitedBookIds.insert(bookId)
    if let seriesId {
      session.visitedSeriesIds.insert(seriesId)
    }
    currentSession = session
  }

  func updateHandoff(sessionID: UUID, title: String, url: URL?) {
    guard var session = currentSession, session.id == sessionID else { return }
    session.handoffTitle = title
    session.handoffURL = url
    currentSession = session
  }

  func updatePresentedBook(sessionID: UUID, book: Book) {
    guard var session = currentSession, session.id == sessionID else { return }
    session.book = book
    currentSession = session
    #if os(iOS)
      ReaderLiveActivityManager.shared.readerDidUpdateBook(book, incognito: session.incognito)
    #endif
  }

  func closeReader(syncVisited: Bool = true) {
    guard let currentSession else { return }

    finishSession(currentSession, syncVisited: syncVisited)

    #if os(iOS)
      ReaderLiveActivityManager.shared.readerDidClose()
    #endif

    #if os(macOS)
      clearReaderCommands()
    #endif

    self.currentSession = nil
  }

  #if os(macOS)
    func configureWindowOpener(_ handler: @escaping () -> Void) {
      openWindowHandler = handler
    }

    func handleReaderWindowAppear() {
      isReaderWindowVisible = true
    }

    func handleReaderWindowDisappear() {
      isReaderWindowVisible = false
      guard currentSession != nil else { return }
      closeReader()
    }

    func configureReaderCommands(
      state: ReaderCommandState,
      handlers: ReaderCommandHandlers
    ) {
      readerCommandState = state
      readerCommandHandlers = handlers
    }

    func updateReaderCommandState(_ state: ReaderCommandState) {
      readerCommandState = state
    }

    func clearReaderCommands() {
      readerCommandState = ReaderCommandState()
      readerCommandHandlers = nil
    }

    func showReaderSettingsFromCommand() {
      readerCommandHandlers?.showReaderSettings()
    }

    func showBookDetailsFromCommand() {
      readerCommandHandlers?.showBookDetails()
    }

    func showTableOfContentsFromCommand() {
      readerCommandHandlers?.showTableOfContents()
    }

    func showPageJumpFromCommand() {
      readerCommandHandlers?.showPageJump()
    }

    func showSearchFromCommand() {
      readerCommandHandlers?.showSearch()
    }

    func openPreviousBookFromCommand() {
      readerCommandHandlers?.openPreviousBook()
    }

    func openNextBookFromCommand() {
      readerCommandHandlers?.openNextBook()
    }

    func setReadingDirectionFromCommand(_ direction: ReadingDirection) {
      readerCommandHandlers?.setReadingDirection(direction)
    }

    func setPageLayoutFromCommand(_ layout: PageLayout) {
      readerCommandHandlers?.setPageLayout(layout)
    }

    func toggleIsolateCoverPageFromCommand() {
      readerCommandHandlers?.toggleIsolateCoverPage()
    }

    func toggleIsolatePageFromCommand(_ pageID: ReaderPageID) {
      readerCommandHandlers?.toggleIsolatePage(pageID)
    }

    func sharePageFromCommand(_ pageID: ReaderPageID) {
      readerCommandHandlers?.sharePage(pageID)
    }

    func setPageRotationFromCommand(_ pageID: ReaderPageID, degrees: Int) {
      readerCommandHandlers?.setPageRotation(pageID, degrees)
    }

    func setSplitWidePageModeFromCommand(_ mode: SplitWidePageMode) {
      readerCommandHandlers?.setSplitWidePageMode(mode)
    }

    func toggleContinuousScrollFromCommand() {
      readerCommandHandlers?.toggleContinuousScroll()
    }
  #endif

  private func finishSession(_ session: ReaderSession, syncVisited: Bool) {
    flushHandlers[session.id]?()
    flushHandlers.removeValue(forKey: session.id)

    guard syncVisited else { return }

    if session.incognito {
      logger.debug("⏭️ [Progress/Checkpoint] Skip visited sync: incognito mode enabled")
      return
    }

    guard !session.visitedBookIds.isEmpty else { return }

    let bookIds = session.visitedBookIds
    let seriesIds = session.visitedSeriesIds
    Task(priority: .utility) {
      logger.debug(
        "⏳ [Progress/Checkpoint] Wait before syncing visited items: books=\(bookIds.count), series=\(seriesIds.count)"
      )
      let checkpoint = await ReaderProgressDispatchService.shared.captureProgressCheckpoint(
        bookIds: bookIds,
        waitForRecentFlush: true
      )
      logger.debug(
        "📍 [Progress/Checkpoint] Captured before visited sync: entries=\(checkpoint.count)"
      )
      let idle = await ReaderProgressDispatchService.shared.waitUntilCheckpointReached(
        checkpoint,
        timeout: .seconds(6)
      )
      if idle {
        logger.debug(
          "✅ [Progress/Checkpoint] Wait completed before visited sync: entries=\(checkpoint.count)"
        )
      } else {
        logger.warning(
          "⚠️ [Progress/Checkpoint] Wait timed out before visited sync, continuing: books=\(bookIds.count), entries=\(checkpoint.count)"
        )
      }
      await SyncService.shared.syncVisitedItems(bookIds: bookIds, seriesIds: seriesIds)
      WidgetDataService.refreshWidgetData()
    }
  }
}
