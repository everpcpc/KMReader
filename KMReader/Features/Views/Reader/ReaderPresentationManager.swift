//
//  ReaderPresentationManager.swift
//  KMReader
//
//  Created by Komga iOS Client
//

import Observation

@MainActor
@Observable
final class ReaderPresentationManager {
  private(set) var readerState: BookReaderState?
  private var onDismiss: (() -> Void)?

  var hideStatusBar: Bool = false

  #if os(macOS)
    private var openWindowHandler: (() -> Void)?
    private var isWindowDrivenClose = false
  #endif

  func present(
    book: Book, incognito: Bool, readList: ReadList? = nil, onDismiss: (() -> Void)? = nil
  ) {
    #if !os(macOS)
      // On iOS/tvOS we need to re-trigger the presentation cycle by dismissing first
      if readerState != nil {
        closeReader(callHandler: false)
      }
    #endif

    let state = BookReaderState(book: book, incognito: incognito, readList: readList)
    readerState = state
    self.onDismiss = onDismiss

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

  func closeReader(callHandler: Bool = true) {
    guard readerState != nil else {
      onDismiss = nil
      return
    }

    #if os(macOS)
      if !isWindowDrivenClose {
        ReaderWindowManager.shared.closeReader()
      }
    #endif

    readerState = nil

    if callHandler {
      let handler = onDismiss
      onDismiss = nil
      handler?()
    } else {
      onDismiss = nil
    }
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
