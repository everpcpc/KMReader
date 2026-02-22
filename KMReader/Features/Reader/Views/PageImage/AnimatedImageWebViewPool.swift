//
// AnimatedImageWebViewPool.swift
//
//

#if canImport(WebKit)
  import Foundation
  import WebKit

  @MainActor
  final class AnimatedImageWebViewPool {
    static let shared = AnimatedImageWebViewPool(maxSize: 4)

    private struct Entry {
      let webView: WKWebView
      var lastAccess: Date
      var lastLoadedURL: URL?
    }

    private var entries: [Int: Entry] = [:]
    private let maxSize: Int

    init(maxSize: Int) {
      self.maxSize = max(1, maxSize)
    }

    func webView(for slot: Int) -> WKWebView {
      let resolvedSlot = Self.resolveSlot(slot)
      if var existing = entries[resolvedSlot] {
        existing.lastAccess = Date()
        entries[resolvedSlot] = existing
        return existing.webView
      }

      let webView = Self.makeWebView()
      entries[resolvedSlot] = Entry(webView: webView, lastAccess: Date(), lastLoadedURL: nil)
      trimIfNeeded(excluding: resolvedSlot)
      return webView
    }

    func loadFileIfNeeded(_ fileURL: URL, slot: Int) -> Bool {
      let resolvedSlot = Self.resolveSlot(slot)
      guard entries[resolvedSlot]?.lastLoadedURL != fileURL else {
        return false
      }

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
      let htmlFileURL = baseDir.appendingPathComponent(".animated_preview_\(resolvedSlot).html")
      do {
        try html.write(to: htmlFileURL, atomically: true, encoding: .utf8)
      } catch {
        return false
      }

      let webView = webView(for: resolvedSlot)
      webView.loadFileURL(htmlFileURL, allowingReadAccessTo: baseDir)

      if var entry = entries[resolvedSlot] {
        entry.lastLoadedURL = fileURL
        entry.lastAccess = Date()
        entries[resolvedSlot] = entry
      }
      return true
    }

    private func trimIfNeeded(excluding slot: Int) {
      guard entries.count > maxSize else { return }

      let overflow = entries.count - maxSize
      let candidates =
        entries
        .filter { $0.key != slot }
        .sorted { $0.value.lastAccess < $1.value.lastAccess }
        .prefix(overflow)

      for candidate in candidates {
        candidate.value.webView.navigationDelegate = nil
        candidate.value.webView.removeFromSuperview()
        entries.removeValue(forKey: candidate.key)
      }
    }

    private static func resolveSlot(_ slot: Int) -> Int {
      max(slot, 0)
    }

    private static func makeWebView() -> WKWebView {
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
    }
  }
#endif
