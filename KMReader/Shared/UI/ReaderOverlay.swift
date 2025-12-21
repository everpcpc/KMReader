//
//  ReaderOverlay.swift
//  KMReader
//

import SwiftUI

#if os(iOS) || os(tvOS)
  struct ReaderOverlay: View {
    @Environment(ReaderPresentationManager.self) private var readerPresentation

    private var isPresented: Bool {
      readerPresentation.readerState != nil
    }

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
      .opacity(isPresented ? 1 : 0)
      .scaleEffect(isPresented ? 1 : 0.5, anchor: .center)
      .allowsHitTesting(isPresented)
      .animation(isPresented ? nil : .easeInOut(duration: 0.3), value: isPresented)
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
