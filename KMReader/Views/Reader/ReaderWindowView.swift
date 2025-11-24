//
//  ReaderWindowView.swift
//  Komga
//
//  Created by Komga iOS Client
//

#if canImport(AppKit)
  import SwiftUI
  import AppKit

  struct ReaderWindowView: View {
    @Environment(\.dismissWindow) private var dismissWindow
    @State private var readerState: BookReaderState?

    var body: some View {
      Group {
        if let state = readerState, let bookId = state.bookId {
          BookReaderView(bookId: bookId, incognito: state.incognito)
            .onDisappear {
              ReaderWindowManager.shared.closeReader()
            }
        } else {
          ProgressView()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
      }
      .task {
        // Get reader state from shared manager
        readerState = ReaderWindowManager.shared.currentState
      }
      .onChange(of: ReaderWindowManager.shared.currentState) { _, newState in
        readerState = newState
        if newState == nil {
          dismissWindow(id: "reader")
        }
      }
    }
  }

#endif
