import SwiftUI

extension View {
  func readerPageScrollTransition() -> some View {
    scrollTransition { content, phase in
      content
        .opacity(phase.isIdentity ? 1 : 0)
        .scaleEffect(phase.isIdentity ? 1 : 0.5)
        .blur(radius: phase.isIdentity ? 0 : 10)
    }
  }
}
