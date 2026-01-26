//
//  ReaderOverlay.swift
//  KMReader
//

import SwiftUI

#if os(iOS) || os(tvOS)
  /// Reader overlay that handles presentation with fullScreenCover
  struct ReaderOverlay: View {
    let namespace: Namespace.ID
    @Environment(ReaderPresentationManager.self) private var readerPresentation
    @AppStorage("themeColorHex") private var themeColor: ThemeColor = .orange

    var body: some View {
      Color.clear
        .frame(width: 0, height: 0)
        .fullScreenCover(
          isPresented: Binding(
            get: { readerPresentation.readerState != nil },
            set: { if !$0 { readerPresentation.closeReader() } }
          )
        ) {
          ReaderContentView()
            #if os(iOS)
              .readerDismissGesture(readingDirection: readerPresentation.readingDirection)
            #endif
            .navigationTransitionZoomIfAvailable(
              sourceID: readerPresentation.sourceBookId,
              in: namespace
            )
            #if os(iOS)
              .tint(themeColor.color)
              .accentColor(themeColor.color)
            #endif
        }
    }
  }

  /// Reader content extracted to be used in fullScreenCover
  private struct ReaderContentView: View {
    @Environment(ReaderPresentationManager.self) private var readerPresentation

    var body: some View {
      Group {
        if let state = readerPresentation.readerState {
          if let book = state.book {
            BookReaderView(
              book: book,
              incognito: state.incognito,
              readList: state.readList,
              onClose: { readerPresentation.closeReader() }
            )
          } else {
            ReaderPlaceholderView {
              readerPresentation.closeReader()
            }
          }
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      #if os(iOS)
        .statusBarHidden(readerPresentation.hideStatusBar)
      #endif
    }
  }

  struct ReaderPlaceholderView: View {
    let onClose: () -> Void

    var body: some View {
      VStack(spacing: 16) {
        ProgressView()
          .progressViewStyle(.circular)

        Text(String(localized: "reader.preparing"))
          .font(.headline)
          .foregroundColor(.secondary)

        Button {
          onClose()
        } label: {
          Label(String(localized: "Cancel"), systemImage: "xmark.circle")
            .font(.headline)
        }
        .adaptiveButtonStyle(.bordered)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(PlatformHelper.systemBackgroundColor.readerIgnoresSafeArea())
    }
  }

#elseif os(macOS)
  struct MacReaderWindowConfigurator: View {
    @Environment(ReaderPresentationManager.self) private var readerPresentation
    let openWindow: () -> Void

    var body: some View {
      Color.clear
        .onAppear {
          readerPresentation.configureWindowOpener(openWindow)
        }
    }
  }
#endif
