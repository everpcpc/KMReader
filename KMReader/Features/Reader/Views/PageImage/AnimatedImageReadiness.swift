//
// AnimatedImageReadiness.swift
//
//

#if canImport(WebKit)
  import Foundation
  import WebKit

  enum AnimatedImageReadiness {
    static let probeScript = """
      (function() {
        const img = document.images && document.images[0];
        return !!(img && img.complete && img.naturalWidth > 0 && img.naturalHeight > 0);
      })();
      """

    static let maxProbeAttempts: Int = 20
    static let probeDelay: TimeInterval = 0.04

    static func isReady(_ result: Any?) -> Bool {
      (result as? Bool) ?? ((result as? NSNumber)?.boolValue ?? false)
    }

    @MainActor
    static func waitUntilReady(
      in webView: WKWebView,
      token: UInt64,
      currentToken: @escaping () -> UInt64,
      attempt: Int = 0,
      onReady: @escaping () -> Void
    ) {
      guard token == currentToken() else { return }

      webView.evaluateJavaScript(probeScript) { result, _ in
        guard token == currentToken() else { return }

        if isReady(result) || attempt >= maxProbeAttempts {
          onReady()
          return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + probeDelay) {
          waitUntilReady(
            in: webView,
            token: token,
            currentToken: currentToken,
            attempt: attempt + 1,
            onReady: onReady
          )
        }
      }
    }
  }
#endif
