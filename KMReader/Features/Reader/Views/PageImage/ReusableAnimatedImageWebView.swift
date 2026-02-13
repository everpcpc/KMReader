//
//  ReusableAnimatedImageWebView.swift
//  KMReader
//

import SwiftUI

#if canImport(WebKit)
  import WebKit

  struct ReusableAnimatedImageWebView: View {
    let fileURL: URL
    let onLoadStateChange: ((Bool) -> Void)?

    init(fileURL: URL, onLoadStateChange: ((Bool) -> Void)? = nil) {
      self.fileURL = fileURL
      self.onLoadStateChange = onLoadStateChange
    }

    var body: some View {
      PlatformWebView(fileURL: fileURL, onLoadStateChange: onLoadStateChange)
        .background(Color.black)
    }

    @MainActor
    private static var lastLoadedURL: URL?

    @MainActor
    private static let sharedWebView: WKWebView = {
      let config = WKWebViewConfiguration()
      config.defaultWebpagePreferences.allowsContentJavaScript = false
      config.suppressesIncrementalRendering = false

      let webView = WKWebView(frame: .zero, configuration: config)

      #if os(iOS)
        webView.isOpaque = false
        webView.scrollView.showsVerticalScrollIndicator = false
        webView.scrollView.showsHorizontalScrollIndicator = false
        webView.scrollView.isScrollEnabled = false
        webView.backgroundColor = .black
        webView.scrollView.backgroundColor = .black
        webView.scrollView.bounces = false
      #elseif os(macOS)
        webView.setValue(false, forKey: "drawsBackground")
      #endif

      return webView
    }()

    @MainActor
    private static func updateWebViewIfNeeded(fileURL: URL) -> Bool {
      guard lastLoadedURL != fileURL else { return false }

      let fileName =
        fileURL.lastPathComponent.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)
        ?? fileURL.lastPathComponent
      let html = """
        <!doctype html>
        <html>
        <head>
        <meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover,user-scalable=no">
        <style>
        html, body {
          margin: 0;
          width: 100%;
          height: 100%;
          background: #000;
          overflow: hidden;
        }
        body {
          display: flex;
          align-items: center;
          justify-content: center;
        }
        img {
          width: 100%;
          height: 100%;
          object-fit: contain;
          image-rendering: auto;
        }
        </style>
        </head>
        <body>
        <img src="\(fileName)" alt="">
        </body>
        </html>
        """

      let baseDir = fileURL.deletingLastPathComponent()
      let htmlFileURL = baseDir.appendingPathComponent(".animated_preview.html")
      do {
        try html.write(to: htmlFileURL, atomically: true, encoding: .utf8)
      } catch {
        return false
      }
      sharedWebView.loadFileURL(htmlFileURL, allowingReadAccessTo: baseDir)
      lastLoadedURL = fileURL
      return true
    }

    #if os(iOS)
      private struct PlatformWebView: UIViewRepresentable {
        let fileURL: URL
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
          let webView = ReusableAnimatedImageWebView.sharedWebView
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
          if ReusableAnimatedImageWebView.updateWebViewIfNeeded(fileURL: fileURL) {
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
          let webView = ReusableAnimatedImageWebView.sharedWebView
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
          if ReusableAnimatedImageWebView.updateWebViewIfNeeded(fileURL: fileURL) {
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
    let onLoadStateChange: ((Bool) -> Void)?

    init(fileURL: URL, onLoadStateChange: ((Bool) -> Void)? = nil) {
      self.fileURL = fileURL
      self.onLoadStateChange = onLoadStateChange
    }

    var body: some View {
      Color.black
    }
  }
#endif
