import SwiftUI

#if os(macOS)
  struct MouseHoverEffect: ViewModifier {
    @State private var isHovering = false

    var scale: CGFloat = 1.03

    func body(content: Content) -> some View {
      content
        .overlay(
          RoundedRectangle(cornerRadius: 12)
            .fill(.white)
            .opacity(isHovering ? 0.08 : 0)
            .allowsHitTesting(false)
        )
        .scaleEffect(isHovering ? scale : 1.0)
        .offset(y: isHovering ? -2 : 0)
        .animation(.easeOut(duration: 0.15), value: isHovering)
        .onHover { hovering in
          isHovering = hovering
        }
    }
  }
#endif

extension View {
  func macHoverEffect() -> some View {
    #if os(macOS)
      self.modifier(MouseHoverEffect())
    #else
      self
    #endif
  }
}
