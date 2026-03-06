//
// ReaderWindowView.swift
//
//

#if os(macOS)
  import AppKit
  import SwiftUI

  struct ReaderWindowView: View {
    let readerPresentation: ReaderPresentationManager
    @Environment(\.dismissWindow) private var dismissWindow

    @AppStorage("autoFullscreenOnOpen") private var autoFullscreenOnOpen: Bool = false

    @State private var didRequestFullscreen: Bool = false

    var body: some View {
      Group {
        if let session = readerPresentation.currentSession {
          BookReaderView(
            sessionID: session.id,
            book: session.book,
            incognito: session.incognito,
            readListContext: session.readListContext,
            readerPresentation: readerPresentation,
            onClose: { readerPresentation.closeReader() }
          )
          .id(session.id)
          .background(WindowTitleUpdater(book: session.book))
          .background(
            WindowFullscreenUpdater(
              shouldEnterFullScreen: autoFullscreenOnOpen,
              didRequestFullscreen: $didRequestFullscreen
            )
          )
        } else {
          ProgressView()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(WindowTitleUpdater(book: nil))
            .background(
              WindowFullscreenUpdater(
                shouldEnterFullScreen: autoFullscreenOnOpen,
                didRequestFullscreen: $didRequestFullscreen
              )
            )
        }
      }
      .komgaHandoff(
        title: readerPresentation.handoffTitle,
        url: readerPresentation.handoffURL,
        scope: .reader
      )
      .onAppear {
        didRequestFullscreen = false

        if readerPresentation.currentSession == nil {
          dismissWindow(id: "reader")
          return
        }

        readerPresentation.handleReaderWindowAppear()
      }
      .onChange(of: readerPresentation.currentSession) { _, newSession in
        guard newSession == nil else { return }
        DispatchQueue.main.async {
          dismissWindow(id: "reader")
        }
      }
      .onDisappear {
        readerPresentation.handleReaderWindowDisappear()
      }
    }
  }

  private struct WindowTitleUpdater: NSViewRepresentable {
    let book: Book?

    func makeNSView(context: Context) -> NSView {
      NSView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {
      updateWindowTitle(nsView: nsView)
    }

    private func updateWindowTitle(nsView: NSView) {
      DispatchQueue.main.async {
        guard let window = nsView.window else {
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            updateWindowTitle(nsView: nsView)
          }
          return
        }

        if let book {
          window.title = "\(book.seriesTitle) - \(book.metadata.title)"
          window.representedURL = nil
        } else {
          window.title = "Reader"
        }
      }
    }
  }

  private struct WindowFullscreenUpdater: NSViewRepresentable {
    let shouldEnterFullScreen: Bool
    @Binding var didRequestFullscreen: Bool

    func makeNSView(context: Context) -> NSView {
      NSView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {
      guard shouldEnterFullScreen, !didRequestFullscreen else { return }
      updateWindowFullScreen(nsView: nsView)
    }

    private func updateWindowFullScreen(nsView: NSView) {
      DispatchQueue.main.async {
        guard let window = nsView.window else {
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            updateWindowFullScreen(nsView: nsView)
          }
          return
        }

        if window.styleMask.contains(.fullScreen) {
          didRequestFullscreen = true
          return
        }

        window.toggleFullScreen(nil)
        didRequestFullscreen = true
      }
    }
  }

#endif
