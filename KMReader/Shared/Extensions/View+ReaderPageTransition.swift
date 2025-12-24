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
      case .fade:
        content
          .scrollTransition(.interactive, axis: axis) { view, phase in
            view
              .opacity(phase.isIdentity ? 1 : 0.3)
          }
      case .scale:
        content
          .scrollTransition(.interactive, axis: axis) { view, phase in
            view
              .scaleEffect(phase.isIdentity ? 1 : 0.8)
              .opacity(phase.isIdentity ? 1 : 0.6)
          }
      case .rotation3D:
        content
          .scrollTransition(.interactive, axis: axis) { view, phase in
            view
              .rotation3DEffect(
                .degrees(phase.value * -45),
                axis: (x: 0, y: 1, z: 0),
                perspective: 0.5
              )
              .opacity(phase.isIdentity ? 1 : 0.7)
          }
      case .cube:
        content
          .scrollTransition(.interactive, axis: axis) { view, phase in
            view
              .rotation3DEffect(
                .degrees(phase.value * -90),
                axis: (x: 0, y: 1, z: 0),
                anchor: phase.value > 0 ? .leading : .trailing,
                perspective: 0.4
              )
              .opacity(phase.isIdentity ? 1 : 0.9)
          }
      }
    #else
      // scrollTransition does not work properly on macOS/tvOS
      content
    #endif
  }
}
