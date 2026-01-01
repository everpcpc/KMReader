//
//  ReaderOverlay.swift
//  KMReader
//

import SwiftUI

#if os(iOS) || os(tvOS)
  /// Reader overlay that handles presentation with zoom transition on iOS 18+
  struct ReaderOverlay: View {
    let namespace: Namespace.ID
    @Environment(ReaderPresentationManager.self) private var readerPresentation
    @AppStorage("themeColorHex") private var themeColor: ThemeColor = .orange

    var body: some View {
      // iOS 18+: Use fullScreenCover for zoom transition
      if #available(iOS 18.0, tvOS 18.0, *) {
        Color.clear
          .frame(width: 0, height: 0)
          .fullScreenCover(
            isPresented: Binding(
              get: { readerPresentation.readerState != nil },
              set: { if !$0 { readerPresentation.closeReader() } }
            )
          ) {
            #if os(iOS)
              ReaderContentView()
                .readerDismissGesture(readingDirection: readerPresentation.readingDirection)
                .ifLet(readerPresentation.sourceBookId) { view, sourceID in
                  view.navigationTransitionZoomIfAvailable(
                    sourceID: sourceID,
                    in: namespace
                  )
                }
                .tint(themeColor.color)
                .accentColor(themeColor.color)
            #else
              ReaderContentView()
                .ifLet(readerPresentation.sourceBookId) { view, sourceID in
                  view.navigationTransitionZoomIfAvailable(
                    sourceID: sourceID,
                    in: namespace
                  )
                }
            #endif
          }
      } else {
        // iOS 17 and earlier: Use overlay with opacity/scale animation
        ReaderOverlayFallback()
      }
    }
  }

  /// Fallback overlay for iOS 17 and earlier
  private struct ReaderOverlayFallback: View {
    @Environment(ReaderPresentationManager.self) private var readerPresentation
    @AppStorage("themeColorHex") private var themeColor: ThemeColor = .orange

    private var isPresented: Bool {
      readerPresentation.readerState != nil && !readerPresentation.isDismissing
    }

    var body: some View {
      Group {
        if readerPresentation.readerState != nil {
          ReaderContentView()
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .readerIgnoresSafeArea()
      #if os(iOS)
        .tint(themeColor.color)
        .accentColor(themeColor.color)
      #endif
      .opacity(isPresented ? 1 : 0)
      .scaleEffect(isPresented ? 1 : 0.5, anchor: .center)
      .allowsHitTesting(isPresented)
      .animation(
        isPresented ? .easeInOut(duration: 0.1) : .easeInOut(duration: 0.2), value: isPresented)
    }
  }

  /// Reader content extracted to be used in both fullScreenCover and overlay
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
      .readerIgnoresSafeArea()
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
          Label(String(localized: "common.cancel"), systemImage: "xmark.circle")
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
