//
//  ReaderWindowManager.swift
//  Komga
//
//  Created by Komga iOS Client
//

#if os(macOS)
  import SwiftUI

  // Manager to pass reader state to window
  @MainActor
  @Observable
  class ReaderWindowManager {
    static let shared = ReaderWindowManager()

    var currentState: BookReaderState? {
      didSet {
        // When state becomes nil, call onDismiss if it hasn't been called yet
        if currentState == nil && oldValue != nil && !hasCalledOnDismiss {
          hasCalledOnDismiss = true
          onDismissCallback?()
          onDismissCallback = nil
        }
      }
    }

    // Track if window is currently open
    var isWindowOpen: Bool = false

    private var onDismissCallback: (() -> Void)?
    private var hasCalledOnDismiss = false

    private init() {}

    func openReader(
      book: Book, incognito: Bool = false, readList: ReadList? = nil,
      openWindow: @escaping () -> Void,
      onDismiss: (() -> Void)? = nil
    ) {
      // Update onDismiss callback if provided
      if let onDismiss = onDismiss {
        onDismissCallback = onDismiss
      }

      // Reset onDismiss flag when opening a new book
      hasCalledOnDismiss = false

      // If window is already open, just update the state (replace content)
      if isWindowOpen {
        currentState = BookReaderState(book: book, incognito: incognito, readList: readList)
      } else {
        // Window not open, open it first
        currentState = BookReaderState(book: book, incognito: incognito, readList: readList)
        openWindow()
        isWindowOpen = true
      }
    }

    func closeReader() {
      isWindowOpen = false
      currentState = nil
    }
  }
#endif
