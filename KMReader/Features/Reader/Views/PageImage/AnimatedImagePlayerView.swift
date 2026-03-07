import SwiftUI

struct AnimatedImagePlayerView: View {
  let sourceFileURL: URL

  var body: some View {
    #if os(iOS) || os(macOS)
      PlatformAnimatedImageView(sourceFileURL: sourceFileURL)
        .background(Color.clear)
        .allowsHitTesting(false)
    #else
      Color.clear
    #endif
  }

  #if os(iOS)
    private struct PlatformAnimatedImageView: UIViewRepresentable {
      let sourceFileURL: URL

      func makeCoordinator() -> Coordinator {
        Coordinator()
      }

      func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        view.layer.contentsGravity = .resizeAspect
        return view
      }

      func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.update(sourceFileURL: sourceFileURL, layer: uiView.layer)
      }

      static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        coordinator.teardown()
      }
    }
  #elseif os(macOS)
    private struct PlatformAnimatedImageView: NSViewRepresentable {
      let sourceFileURL: URL

      func makeCoordinator() -> Coordinator {
        Coordinator()
      }

      func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.wantsLayer = true
        view.layer?.contentsGravity = .resizeAspect
        view.layer?.backgroundColor = CGColor(red: 0, green: 0, blue: 0, alpha: 0)
        return view
      }

      func updateNSView(_ nsView: NSView, context: Context) {
        guard let layer = nsView.layer else { return }
        context.coordinator.update(sourceFileURL: sourceFileURL, layer: layer)
      }

      static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.teardown()
      }
    }
  #endif

  #if os(iOS) || os(macOS)
    @MainActor
    private final class Coordinator {
      private var currentURL: URL?
      private let controller = AnimatedImagePlayerController()

      func update(sourceFileURL: URL, layer: CALayer) {
        if currentURL == sourceFileURL {
          return
        }
        currentURL = sourceFileURL
        controller.start(sourceFileURL: sourceFileURL, targetLayer: layer)
      }

      func teardown() {
        controller.stop()
        currentURL = nil
      }
    }
  #endif
}
