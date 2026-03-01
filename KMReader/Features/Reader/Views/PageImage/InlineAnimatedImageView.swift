//
// InlineAnimatedImageView.swift
//
//

import SwiftUI

struct InlineAnimatedImageView: View {
  let fileURL: URL

  @State private var videoReady = false

  var body: some View {
    LoopingVideoPlayerView(
      videoURL: fileURL,
      onLoadStateChange: handleLoadState
    )
    .opacity(videoReady ? 1 : 0)
    .allowsHitTesting(false)
    .onChange(of: fileURL) { _, _ in
      videoReady = false
    }
  }

  private func handleLoadState(_ isReady: Bool) {
    guard videoReady != isReady else { return }
    videoReady = isReady
  }
}
