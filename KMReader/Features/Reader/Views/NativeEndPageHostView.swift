import SwiftUI

#if os(iOS) || os(tvOS)
  struct NativeEndPageHostView: UIViewRepresentable {
    let previousBook: Book?
    let nextBook: Book?
    let readListContext: ReaderReadListContext?
    let readingDirection: ReadingDirection
    let renderConfig: ReaderRenderConfig
    let onDismiss: () -> Void

    func makeUIView(context: Context) -> NativeEndPageContentView {
      NativeEndPageContentView()
    }

    func updateUIView(_ uiView: NativeEndPageContentView, context: Context) {
      uiView.configure(
        previousBook: previousBook,
        nextBook: nextBook,
        readListContext: readListContext,
        readingDirection: readingDirection,
        renderConfig: renderConfig,
        onDismiss: onDismiss
      )
    }
  }
#elseif os(macOS)
  struct NativeEndPageHostView: NSViewRepresentable {
    let previousBook: Book?
    let nextBook: Book?
    let readListContext: ReaderReadListContext?
    let readingDirection: ReadingDirection
    let renderConfig: ReaderRenderConfig
    let onDismiss: () -> Void

    func makeNSView(context: Context) -> NativeEndPageContentView {
      NativeEndPageContentView()
    }

    func updateNSView(_ nsView: NativeEndPageContentView, context: Context) {
      nsView.configure(
        previousBook: previousBook,
        nextBook: nextBook,
        readListContext: readListContext,
        readingDirection: readingDirection,
        renderConfig: renderConfig,
        onDismiss: onDismiss
      )
    }
  }
#endif
