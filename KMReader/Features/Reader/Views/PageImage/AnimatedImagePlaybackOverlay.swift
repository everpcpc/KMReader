//
// AnimatedImagePlaybackOverlay.swift
//
//

import SwiftUI

struct AnimatedImagePlaybackOverlay: View {
  let fileURL: URL
  let onClose: () -> Void

  @State private var webContentReady = false
  @State private var closeButtonVisible = true

  var body: some View {
    ZStack(alignment: .topTrailing) {
      Color.black.opacity(0.95)
        .readerIgnoresSafeArea()

      ReusableAnimatedImageWebView(
        fileURL: fileURL,
        onLoadStateChange: handleWebContentLoadState
      )
      .readerIgnoresSafeArea()
      .opacity(webContentReady ? 1 : 0)

      Color.clear
        .readerIgnoresSafeArea()
        .contentShape(Rectangle())
        .onTapGesture {
          toggleCloseButtonVisibility()
        }

      if closeButtonVisible {
        Button(action: onClose) {
          Image(systemName: "xmark")
        }
        .buttonBorderShape(.circle)
        .controlSize(.large)
        .adaptiveButtonStyle(.bordered)
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
        .padding(.top, 18)
        .padding(.trailing, 18)
      }
    }
    .transition(.opacity)
    .onAppear {
      webContentReady = false
      closeButtonVisible = true
    }
    .onDisappear {
      webContentReady = false
      closeButtonVisible = true
    }
    .onChange(of: fileURL) { _, _ in
      webContentReady = false
      closeButtonVisible = true
    }
  }

  private func handleWebContentLoadState(_ isReady: Bool) {
    guard webContentReady != isReady else { return }
    withAnimation(.easeInOut(duration: 0.18)) {
      webContentReady = isReady
    }
  }

  private func toggleCloseButtonVisibility() {
    withAnimation(.easeInOut(duration: 0.2)) {
      closeButtonVisible.toggle()
    }
  }
}
