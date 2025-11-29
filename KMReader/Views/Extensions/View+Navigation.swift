//
//  View+Navigation.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

extension View {
  /// Apply inline navigation bar title style on supported platforms.
  /// - On iOS: sets navigation title and uses `.navigationBarTitleDisplayMode(.inline)`
  /// - On macOS: sets navigation title only
  /// - On other platforms (tvOS, etc.): no-op (does not set title)
  func inlineNavigationBarTitle(_ title: String) -> some View {
    #if os(iOS)
      return self.navigationTitle(title).navigationBarTitleDisplayMode(.inline)
    #elseif os(macOS)
      return self.navigationTitle(title)
    #else
      return self
    #endif
  }

  func handleNavigation() -> some View {
    self
      .navigationDestination(for: NavDestination.self) { destination in
        switch destination {
        case .seriesDetail(let seriesId):
          SeriesDetailView(seriesId: seriesId)
        case .bookDetail(let bookId):
          BookDetailView(bookId: bookId)
        case .collectionDetail(let collectionId):
          CollectionDetailView(collectionId: collectionId)
        case .readListDetail(let readListId):
          ReadListDetailView(readListId: readListId)

        case .settingsLibraries:
          SettingsLibrariesView()
        case .settingsAppearance:
          SettingsAppearanceView()
        case .settingsCache:
          SettingsCacheView()
        case .settingsReader:
          SettingsReaderView()
        case .settingsServerInfo:
          SettingsServerInfoView()
        case .settingsMetrics:
          SettingsMetricsView()
        case .settingsAuthenticationActivity:
          AuthenticationActivityView()
        case .settingsServers:
          SettingsServersView()
        }
      }
  }

  #if canImport(AppKit)
    /// Handle reader window opening/closing based on readerState changes
    func handleReaderWindow(readerState: Binding<BookReaderState?>, onDismiss: (() -> Void)? = nil)
      -> some View
    {
      self.background(
        ReaderWindowHandler(readerState: readerState, onDismiss: onDismiss)
      )
    }
  #endif
}

#if canImport(AppKit)
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
