import SwiftUI

extension View {
  @ViewBuilder
  func readerPageScrollTransition(axis: Axis = .horizontal) -> some View {
    modifier(ReaderPageScrollTransitionModifier(axis: axis))
  }
}

private struct ReaderPageScrollTransitionModifier: ViewModifier {
  let axis: Axis

  @AppStorage("scrollPageTransitionStyle") private var style: ScrollPageTransitionStyle = .default

  func body(content: Content) -> some View {
    #if os(iOS)
      switch style {
      case .default:
        content
      case .fancy:
        content
          .scrollTransition(.interactive, axis: axis) { view, phase in
            view
              .opacity(phase.isIdentity ? 1 : 0.3)
              .scaleEffect(phase.isIdentity ? 1 : 0.92)
              .blur(radius: phase.isIdentity ? 0 : 3)
          }
      }
    #else
      // scrollTransition does not work properly on macOS/tvOS
      content
    #endif
  }
}
