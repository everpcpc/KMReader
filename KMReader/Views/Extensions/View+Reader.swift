//
//  View+Navigation.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

extension View {
  /// Present reader view based on platform
  /// - On iOS/tvOS: uses fullScreenCover
  /// - On macOS: uses handleReaderWindow
  func readerPresentation(readerState: Binding<BookReaderState?>, onDismiss: (() -> Void)? = nil)
    -> some View
  {
    #if os(iOS) || os(tvOS)
      let isPresented = Binding(
        get: { readerState.wrappedValue != nil },
        set: { if !$0 { readerState.wrappedValue = nil } }
      )
      return self.fullScreenCover(
        isPresented: isPresented,
        onDismiss: onDismiss
      ) {
        if let state = readerState.wrappedValue, let book = state.book {
          BookReaderView(book: book, incognito: state.incognito)
            .transition(.scale.animation(.easeInOut))
        }
      }
    #elseif os(macOS)
      return self.background(
        ReaderWindowHandler(readerState: readerState, onDismiss: onDismiss)
      )
    #else
      return self
    #endif
  }
}

#if os(macOS)
  private struct ReaderWindowHandler: View {
    @Binding var readerState: BookReaderState?
    @Environment(\.openWindow) private var openWindow
    let onDismiss: (() -> Void)?

    var body: some View {
      Color.clear
        .onChange(of: readerState) { _, newValue in
          if let state = newValue, let book = state.book {
            // Manager will handle closing existing window if needed
            ReaderWindowManager.shared.openReader(
              book: book,
              incognito: state.incognito,
              openWindow: {
                openWindow(id: "reader")
              },
              onDismiss: onDismiss
            )
          } else {
            // Only close if manager state is not already nil
            if ReaderWindowManager.shared.currentState != nil {
              ReaderWindowManager.shared.closeReader()
            }
          }
        }
        .onChange(of: ReaderWindowManager.shared.currentState) { oldState, newState in
          // When manager state becomes nil (window closed), clear readerState
          if newState == nil && oldState != nil {
            // Also clear the readerState in the calling view
            if readerState != nil {
              readerState = nil
            }
            // onDismiss is now handled by ReaderWindowManager
          }
        }
    }
  }
#endif
