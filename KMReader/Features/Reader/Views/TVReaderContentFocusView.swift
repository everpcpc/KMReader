#if os(tvOS)
  import SwiftUI

  struct TVReaderContentFocusView<Content: View>: View {
    let showingControls: Bool
    let currentViewItem: ReaderViewItem?
    let onActivate: () -> Void
    let content: Content

    @FocusState private var isContentAnchorFocused: Bool
    private let logger = AppLogger(.reader)

    init(
      showingControls: Bool,
      currentViewItem: ReaderViewItem?,
      onActivate: @escaping () -> Void,
      @ViewBuilder content: () -> Content
    ) {
      self.showingControls = showingControls
      self.currentViewItem = currentViewItem
      self.onActivate = onActivate
      self.content = content()
    }

    var body: some View {
      content
        .overlay(alignment: .topLeading) {
          Button {
            logger.debug("📺 content anchor select: toggle controls")
            onActivate()
          } label: {
            Color.clear
              .frame(width: 1, height: 1)
          }
          .buttonStyle(.plain)
          .focusable(!showingControls)
          .focused($isContentAnchorFocused)
          .opacity(0.001)
        }
        .onAppear {
          updateContentAnchorFocus()
        }
        .onChange(of: showingControls) { _, _ in
          logger.debug(
            "📺 showingControls changed in TVReaderContentFocusView: \(showingControls), currentViewItem=\(String(describing: currentViewItem))"
          )
          if showingControls {
            isContentAnchorFocused = false
          } else {
            DispatchQueue.main.async {
              updateContentAnchorFocus()
            }
          }
        }
        .onChange(of: currentViewItem) { _, _ in
          logger.debug("📺 currentViewItem changed: \(String(describing: currentViewItem))")
          updateContentAnchorFocus()
        }
        .onChange(of: isContentAnchorFocused) { _, newValue in
          logger.debug(
            "📺 content anchor focus changed: \(newValue), showingControls=\(showingControls)"
          )
          if !newValue && !showingControls {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
              updateContentAnchorFocus()
            }
          }
        }
    }

    private func updateContentAnchorFocus() {
      guard !showingControls else {
        logger.debug("📺 updateContentAnchorFocus -> blur (controls visible)")
        isContentAnchorFocused = false
        return
      }

      logger.debug("📺 updateContentAnchorFocus -> focus content anchor")
      isContentAnchorFocused = true
    }
  }
#endif
