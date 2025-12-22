import SwiftUI

extension View {
  @ViewBuilder
  func readerPageScrollTransition(style: ScrollPageTransitionStyle, axis: Axis = .horizontal)
    -> some View
  {
    #if os(iOS)
      switch style {
      case .default:
        self
      case .fancy:
        scrollTransition(.interactive, axis: axis) {
          content,
          phase in
          content
            .opacity(phase.isIdentity ? 1 : 0.3)
            .scaleEffect(phase.isIdentity ? 1 : 0.92)
            .blur(radius: phase.isIdentity ? 0 : 3)
        }
      }
    #else
      // scrollTransition does not work properly on macOS/tvOS
      self
    #endif
  }
}
