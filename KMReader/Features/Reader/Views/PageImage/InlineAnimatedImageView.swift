//
// InlineAnimatedImageView.swift
//
//

import SwiftUI

struct InlineAnimatedImageView: View {
  let fileURL: URL
  let poolSlot: Int

  @State private var webContentReady = false

  var body: some View {
    ReusableAnimatedImageWebView(
      fileURL: fileURL,
      poolSlot: poolSlot,
      onLoadStateChange: handleLoadState
    )
    .opacity(webContentReady ? 1 : 0)
    .allowsHitTesting(false)
    .onChange(of: fileURL) { _, _ in
      webContentReady = false
    }
  }

  private func handleLoadState(_ isReady: Bool) {
    guard webContentReady != isReady else { return }
    webContentReady = isReady
  }
}
