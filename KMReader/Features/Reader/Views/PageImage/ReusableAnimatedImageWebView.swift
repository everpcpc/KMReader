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
        .background(Color.clear)
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
          container.backgroundColor = .clear
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
            webView.alpha = 0
            coordinator.markLoading()
          } else {
            webView.alpha = 1
            coordinator.markLoaded()
          }
        }

        final class Coordinator: NSObject, WKNavigationDelegate {
          var onLoadStateChange: ((Bool) -> Void)?
          private var readinessToken: UInt64 = 0

          init(onLoadStateChange: ((Bool) -> Void)?) {
            self.onLoadStateChange = onLoadStateChange
          }

          func markLoading() {
            readinessToken &+= 1
            emitLoadState(false, token: readinessToken)
          }

          func markLoaded() {
            readinessToken &+= 1
            emitLoadState(true, token: readinessToken)
          }

          private func emitLoadState(_ isReady: Bool, token: UInt64) {
            Task { @MainActor in
              guard self.readinessToken == token else { return }
              self.onLoadStateChange?(isReady)
            }
          }

          func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            let token = readinessToken
            AnimatedImageReadiness.waitUntilReady(
              in: webView,
              token: token,
              currentToken: { [weak self] in self?.readinessToken ?? 0 }
            ) { [weak self, weak webView] in
              guard let self, let webView else { return }
              webView.alpha = 1
              self.emitLoadState(true, token: token)
            }
          }

          func webView(
            _ webView: WKWebView,
            didFail navigation: WKNavigation!,
            withError error: Error
          ) {
            webView.alpha = 1
            markLoaded()
          }

          func webView(
            _ webView: WKWebView,
            didFailProvisionalNavigation navigation: WKNavigation!,
            withError error: Error
          ) {
            webView.alpha = 1
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
          container.layer?.backgroundColor = NSColor.clear.cgColor
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
            webView.alphaValue = 0
            coordinator.markLoading()
          } else {
            webView.alphaValue = 1
            coordinator.markLoaded()
          }
        }

        final class Coordinator: NSObject, WKNavigationDelegate {
          var onLoadStateChange: ((Bool) -> Void)?
          private var readinessToken: UInt64 = 0

          init(onLoadStateChange: ((Bool) -> Void)?) {
            self.onLoadStateChange = onLoadStateChange
          }

          func markLoading() {
            readinessToken &+= 1
            emitLoadState(false, token: readinessToken)
          }

          func markLoaded() {
            readinessToken &+= 1
            emitLoadState(true, token: readinessToken)
          }

          private func emitLoadState(_ isReady: Bool, token: UInt64) {
            Task { @MainActor in
              guard self.readinessToken == token else { return }
              self.onLoadStateChange?(isReady)
            }
          }

          func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            let token = readinessToken
            AnimatedImageReadiness.waitUntilReady(
              in: webView,
              token: token,
              currentToken: { [weak self] in self?.readinessToken ?? 0 }
            ) { [weak self, weak webView] in
              guard let self, let webView else { return }
              webView.alphaValue = 1
              self.emitLoadState(true, token: token)
            }
          }

          func webView(
            _ webView: WKWebView,
            didFail navigation: WKNavigation!,
            withError error: Error
          ) {
            webView.alphaValue = 1
            markLoaded()
          }

          func webView(
            _ webView: WKWebView,
            didFailProvisionalNavigation navigation: WKNavigation!,
            withError error: Error
          ) {
            webView.alphaValue = 1
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
