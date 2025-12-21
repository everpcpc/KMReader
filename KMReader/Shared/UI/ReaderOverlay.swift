//
//  ReaderOverlay.swift
//  KMReader
//

import SwiftUI

#if os(iOS) || os(tvOS)
  struct ReaderOverlay: View {
    @Environment(ReaderPresentationManager.self) private var readerPresentation

    var body: some View {
      ZStack {
        if let state = readerPresentation.readerState {
          Color.black.opacity(0.35)
            .readerIgnoresSafeArea()
            .transition(.opacity)

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
      .allowsHitTesting(readerPresentation.readerState != nil)
      .transition(.opacity)
      .animation(
        .spring(response: 0.4, dampingFraction: 0.9, blendDuration: 0.1),
        value: readerPresentation.readerState != nil
      )
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
          Label(String(localized: "common.cancel"), systemImage: "xmark.circle")
            .font(.headline)
        }
        .adaptiveButtonStyle(.bordered)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(PlatformHelper.systemBackgroundColor.ignoresSafeArea())
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
