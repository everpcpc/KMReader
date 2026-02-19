//
// AnimatedImagePlayButton.swift
//
//

import SwiftUI

struct AnimatedImagePlayButton: View {
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Image(systemName: "play.fill")
        .imageScale(.large)
    }
    .buttonBorderShape(.circle)
    .controlSize(.large)
    .adaptiveButtonStyle(.bordered)
    .contentShape(Circle())
  }
}
