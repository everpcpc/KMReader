//
// ReusableAnimatedImageWebView.swift
//
//

import SwiftUI

#if canImport(WebKit)
  import WebKit

  struct ReusableAnimatedImageWebView: View {
    let fileURL: URL
    let poolSlot: Int
    let onLoadStateChange: ((Bool) -> Void)?

    init(fileURL: URL, poolSlot: Int = 0, onLoadStateChange: ((Bool) -> Void)? = nil) {
      self.fileURL = fileURL
      self.poolSlot = poolSlot
      self.onLoadStateChange = onLoadStateChange
    }

    var body: some View {
      PlatformWebView(fileURL: fileURL, poolSlot: poolSlot, onLoadStateChange: onLoadStateChange)
        .background(Color.black)
    }

    @MainActor
    private static func webView(for slot: Int) -> WKWebView {
      AnimatedImageWebViewPool.shared.webView(for: slot)
    }

    @MainActor
    private static func updateWebViewIfNeeded(webView: WKWebView, fileURL: URL, slot: Int) -> Bool {
      AnimatedImageWebViewPool.shared.loadFileIfNeeded(fileURL, slot: slot)
    }

    #if os(iOS)
      private struct PlatformWebView: UIViewRepresentable {
        let fileURL: URL
        let poolSlot: Int
        var onLoadStateChange: ((Bool) -> Void)?

        func makeCoordinator() -> Coordinator {
          Coordinator(onLoadStateChange: onLoadStateChange)
        }

        @MainActor
        func makeUIView(context: Context) -> UIView {
          let container = UIView()
          container.backgroundColor = .black
          attachSharedWebView(to: container, coordinator: context.coordinator)
          return container
        }

        @MainActor
        func updateUIView(_ uiView: UIView, context: Context) {
          context.coordinator.onLoadStateChange = onLoadStateChange
          attachSharedWebView(to: uiView, coordinator: context.coordinator)
        }

        @MainActor
        private func attachSharedWebView(to container: UIView, coordinator: Coordinator) {
          let webView = ReusableAnimatedImageWebView.webView(for: poolSlot)
          webView.navigationDelegate = coordinator
          if webView.superview !== container {
            webView.removeFromSuperview()
            webView.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(webView)
            NSLayoutConstraint.activate([
              webView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
              webView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
              webView.topAnchor.constraint(equalTo: container.topAnchor),
              webView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            ])
          }
          if ReusableAnimatedImageWebView.updateWebViewIfNeeded(
            webView: webView,
            fileURL: fileURL,
            slot: poolSlot
          ) {
            coordinator.markLoading()
          } else {
            coordinator.markLoaded()
          }
        }

        final class Coordinator: NSObject, WKNavigationDelegate {
          var onLoadStateChange: ((Bool) -> Void)?

          init(onLoadStateChange: ((Bool) -> Void)?) {
            self.onLoadStateChange = onLoadStateChange
          }

          func markLoading() {
            Task { @MainActor in
              self.onLoadStateChange?(false)
            }
          }

          func markLoaded() {
            Task { @MainActor in
              self.onLoadStateChange?(true)
            }
          }

          func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            markLoaded()
          }

          func webView(
            _ webView: WKWebView,
            didFail navigation: WKNavigation!,
            withError error: Error
          ) {
            markLoaded()
          }

          func webView(
            _ webView: WKWebView,
            didFailProvisionalNavigation navigation: WKNavigation!,
            withError error: Error
          ) {
            markLoaded()
          }
        }
      }
    #elseif os(macOS)
      private struct PlatformWebView: NSViewRepresentable {
        let fileURL: URL
        let poolSlot: Int
        var onLoadStateChange: ((Bool) -> Void)?

        func makeCoordinator() -> Coordinator {
          Coordinator(onLoadStateChange: onLoadStateChange)
        }

        @MainActor
        func makeNSView(context: Context) -> NSView {
          let container = NSView()
          container.wantsLayer = true
          container.layer?.backgroundColor = NSColor.black.cgColor
          attachSharedWebView(to: container, coordinator: context.coordinator)
          return container
        }

        @MainActor
        func updateNSView(_ nsView: NSView, context: Context) {
          context.coordinator.onLoadStateChange = onLoadStateChange
          attachSharedWebView(to: nsView, coordinator: context.coordinator)
        }

        @MainActor
        private func attachSharedWebView(to container: NSView, coordinator: Coordinator) {
          let webView = ReusableAnimatedImageWebView.webView(for: poolSlot)
          webView.navigationDelegate = coordinator
          if webView.superview !== container {
            webView.removeFromSuperview()
            webView.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(webView)
            NSLayoutConstraint.activate([
              webView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
              webView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
              webView.topAnchor.constraint(equalTo: container.topAnchor),
              webView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            ])
          }
          if ReusableAnimatedImageWebView.updateWebViewIfNeeded(
            webView: webView,
            fileURL: fileURL,
            slot: poolSlot
          ) {
            coordinator.markLoading()
          } else {
            coordinator.markLoaded()
          }
        }

        final class Coordinator: NSObject, WKNavigationDelegate {
          var onLoadStateChange: ((Bool) -> Void)?

          init(onLoadStateChange: ((Bool) -> Void)?) {
            self.onLoadStateChange = onLoadStateChange
          }

          func markLoading() {
            Task { @MainActor in
              self.onLoadStateChange?(false)
            }
          }

          func markLoaded() {
            Task { @MainActor in
              self.onLoadStateChange?(true)
            }
          }

          func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            markLoaded()
          }

          func webView(
            _ webView: WKWebView,
            didFail navigation: WKNavigation!,
            withError error: Error
          ) {
            markLoaded()
          }

          func webView(
            _ webView: WKWebView,
            didFailProvisionalNavigation navigation: WKNavigation!,
            withError error: Error
          ) {
            markLoaded()
          }
        }
      }
    #endif
  }
#else
  struct ReusableAnimatedImageWebView: View {
    let fileURL: URL
    let poolSlot: Int
    let onLoadStateChange: ((Bool) -> Void)?

    init(fileURL: URL, poolSlot: Int = 0, onLoadStateChange: ((Bool) -> Void)? = nil) {
      self.fileURL = fileURL
      self.poolSlot = poolSlot
      self.onLoadStateChange = onLoadStateChange
    }

    var body: some View {
      Color.black
    }
  }
#endif
