//
//  ReaderPresentationManager.swift
//  KMReader
//
//  Created by Komga iOS Client
//

import Foundation
import Observation

@MainActor
@Observable
final class ReaderPresentationManager {
  private(set) var readerState: BookReaderState?

  var hideStatusBar: Bool = false
  var isDismissing: Bool = false
  var readingDirection: ReadingDirection = .ltr

  /// Book ID used as source for zoom transition (iOS 18+)
  private(set) var sourceBookId: String?

  /// Track all book IDs visited during this reader session
  private(set) var visitedBookIds: Set<String> = []
  /// Track all series IDs visited during this reader session
  private(set) var visitedSeriesIds: Set<String> = []

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
    book: Book, incognito: Bool, readList: ReadList? = nil
  ) {
    #if !os(macOS)
      // On iOS/tvOS we need to re-trigger the presentation cycle by dismissing first
      if readerState != nil {
        closeReader(syncVisited: false)
      }
    #endif

    isDismissing = false
    sourceBookId = book.id
    // Reset tracking sets for new session
    visitedBookIds = []
    visitedSeriesIds = []
    let state = BookReaderState(book: book, incognito: incognito, readList: readList)
    readerState = state

    #if os(macOS)
      guard let openWindowHandler else {
        assertionFailure("Reader window opener not configured")
        return
      }

      ReaderWindowManager.shared.openReader(
        book: book,
        incognito: incognito,
        readList: readList,
        openWindow: openWindowHandler,
        onDismiss: { [weak self] in
          self?.handleWindowDismissal()
        }
      )
    #endif
  }

  func closeReader(syncVisited: Bool = true) {
    guard readerState != nil else {
      return
    }

    isDismissing = true
    hideStatusBar = false

    #if os(macOS)
      if !isWindowDrivenClose {
        ReaderWindowManager.shared.closeReader()
      }
      // macOS uses window dismissal, clear immediately
      readerState = nil
    #endif

    // Sync all visited books and series concurrently
    if syncVisited && !visitedBookIds.isEmpty {
      let bookIds = visitedBookIds
      let seriesIds = visitedSeriesIds
      Task {
        await SyncService.shared.syncVisitedItems(bookIds: bookIds, seriesIds: seriesIds)
      }
    }

    // iOS/tvOS: handle state cleanup
    #if os(iOS) || os(tvOS)
      if #available(iOS 18.0, tvOS 18.0, *) {
        // iOS 18+: fullScreenCover handles animation automatically, clear immediately
        readerState = nil
        isDismissing = false
      } else {
        // iOS 17 and earlier: delay clearing readerState until custom animation completes
        // This preserves view identity and prevents scroll reset
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
          self?.readerState = nil
          self?.isDismissing = false
        }
      }
    #else
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
        self?.isDismissing = false
      }
    #endif
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
