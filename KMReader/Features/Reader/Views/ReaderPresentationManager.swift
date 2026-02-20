//
// ReaderPresentationManager.swift
//
//

import Foundation
import Observation

@MainActor
@Observable
final class ReaderPresentationManager {
  private(set) var readerState: BookReaderState?
  private let logger = AppLogger(.reader)

  var hideStatusBar: Bool = false
  var readingDirection: ReadingDirection = .ltr
  var handoffTitle: String = ""
  var handoffURL: URL?

  /// Book ID used as source for zoom transition (iOS 18+)
  private(set) var sourceBookId: String?

  /// Track all book IDs visited during this reader session
  private(set) var visitedBookIds: Set<String> = []
  /// Track all series IDs visited during this reader session
  private(set) var visitedSeriesIds: Set<String> = []

  /// Closure that flushes the current reader's progress (set by the active reader view)
  private(set) var readerFlushHandler: (@MainActor () -> Void)?

  #if os(macOS)
    private var openWindowHandler: (() -> Void)?
    private var isWindowDrivenClose = false
  #endif

  /// Track a visited book and its series during the current reader session
  func trackVisitedBook(bookId: String, seriesId: String?) {
    visitedBookIds.insert(bookId)
    if let seriesId {
      visitedSeriesIds.insert(seriesId)
    }
  }

  func present(
    book: Book,
    incognito: Bool,
    readListContext: ReaderReadListContext? = nil
  ) {
    #if !os(macOS)
      // On iOS/tvOS we need to re-trigger the presentation cycle by dismissing first
      if readerState != nil {
        closeReader(syncVisited: false)
      }
    #endif

    sourceBookId = book.id
    // Reset tracking sets for new session
    visitedBookIds = []
    visitedSeriesIds = []
    let state = BookReaderState(
      book: book,
      incognito: incognito,
      readListContext: readListContext
    )
    readerState = state

    #if os(macOS)
      guard let openWindowHandler else {
        assertionFailure("Reader window opener not configured")
        return
      }

      ReaderWindowManager.shared.openReader(
        book: book,
        incognito: incognito,
        readListContext: readListContext,
        openWindow: openWindowHandler,
        onDismiss: { [weak self] in
          self?.handleWindowDismissal()
        }
      )
    #endif
  }

  func setReaderFlushHandler(_ handler: (@MainActor () -> Void)?) {
    readerFlushHandler = handler
  }

  func closeReader(syncVisited: Bool = true) {
    guard readerState != nil else {
      return
    }
    let isIncognito = readerState?.incognito ?? false

    // Flush progress before clearing reader state to avoid race with waitUntilSettled
    readerFlushHandler?()
    readerFlushHandler = nil

    hideStatusBar = false
    clearHandoff()

    #if os(macOS)
      if !isWindowDrivenClose {
        ReaderWindowManager.shared.closeReader()
      }
    #endif

    // Sync all visited books and series concurrently
    if syncVisited && !isIncognito && !visitedBookIds.isEmpty {
      let bookIds = visitedBookIds
      let seriesIds = visitedSeriesIds
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
    } else if syncVisited && isIncognito {
      logger.debug("⏭️ [Progress/Checkpoint] Skip visited sync: incognito mode enabled")
    }

    readerState = nil
    sourceBookId = nil
  }

  func updateHandoff(title: String, url: URL?) {
    handoffTitle = title
    handoffURL = url
  }

  func clearHandoff() {
    handoffTitle = ""
    handoffURL = nil
  }

  #if os(macOS)
    func configureWindowOpener(_ handler: @escaping () -> Void) {
      openWindowHandler = handler
    }

    private func handleWindowDismissal() {
      isWindowDrivenClose = true
      closeReader()
      isWindowDrivenClose = false
    }
  #endif
}
