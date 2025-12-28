import SwiftUI

struct PlatformShadowModifier: ViewModifier {
  @Environment(\.colorScheme) private var colorScheme
  var cornerRadius: CGFloat = 8

  func body(content: Content) -> some View {
    content
      .background {
        RoundedRectangle(cornerRadius: cornerRadius)
          .fill(colorScheme == .light ? Color.black.opacity(0.3) : Color.white.opacity(0.15))
          .offset(y: colorScheme == .light ? 12 : 6)
          .blur(radius: colorScheme == .light ? 12 : 12)
          .scaleEffect(x: 0.9)
      }
      .shadow(
        color: colorScheme == .light ? .black.opacity(0.15) : .white.opacity(0.1),
        radius: 2,
        x: 0,
        y: 1
      )
  }
}

extension View {
  func platformShadow(cornerRadius: CGFloat = 8) -> some View {
    modifier(PlatformShadowModifier(cornerRadius: cornerRadius))
  }
}
