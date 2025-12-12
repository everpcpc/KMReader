import SwiftUI

extension View {
  @ViewBuilder
  func readerPageScrollTransition(style: PageTransitionStyle) -> some View {
    switch style {
    case .none, .default:
      self
    case .simple:
      scrollTransition(.interactive, axis: .horizontal) { content, phase in
        content
          .opacity(phase.isIdentity ? 1 : 0.5)
      }
    case .fancy:
      scrollTransition(.interactive, axis: .horizontal) { content, phase in
        content
          .opacity(phase.isIdentity ? 1 : 0.3)
          .scaleEffect(phase.isIdentity ? 1 : 0.92)
          .blur(radius: phase.isIdentity ? 0 : 3)
      }
    }
  }
}
