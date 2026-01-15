import SwiftUI

#if os(macOS)
  struct MouseHoverEffect: ViewModifier {
    @State private var isHovering = false

    var scale: CGFloat = 1.02
    var liftAmount: CGFloat = 2.0

    func body(content: Content) -> some View {
      content
        .overlay(
          RoundedRectangle(cornerRadius: 12)
            .fill(.white)
            .opacity(isHovering ? 0.1 : 0)
            .allowsHitTesting(false)
        )
        .scaleEffect(isHovering ? scale : 1.0)
        .offset(y: isHovering ? -liftAmount : 0)
        .shadow(
          color: .black.opacity(isHovering ? 0.3 : 0.1),
          radius: isHovering ? 12 : 4,
          x: 0,
          y: isHovering ? 8 : 2
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovering)
        .onHover { hovering in
          isHovering = hovering
        }
        .contentShape(Rectangle())
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
