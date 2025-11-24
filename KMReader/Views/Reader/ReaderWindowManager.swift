//
//  ReaderWindowManager.swift
//  Komga
//
//  Created by Komga iOS Client
//

#if canImport(AppKit)
  import SwiftUI

  // Manager to pass reader state to window
  @MainActor
  @Observable
  class ReaderWindowManager {
    static let shared = ReaderWindowManager()
    var currentState: BookReaderState?

    private init() {}

    func openReader(bookId: String, incognito: Bool = false) {
      currentState = BookReaderState(bookId: bookId, incognito: incognito)
    }

    func closeReader() {
      currentState = nil
    }
  }
#endif
