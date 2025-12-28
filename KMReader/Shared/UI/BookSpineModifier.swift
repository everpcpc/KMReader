import SwiftUI

struct BookSpineModifier: ViewModifier {
  @Environment(\.colorScheme) private var colorScheme

  func body(content: Content) -> some View {
    content
      .overlay(alignment: .leading) {
        // Main curvature shadow/highlight
        LinearGradient(
          stops: [
            .init(color: .black.opacity(0.15), location: 0),
            .init(color: .white.opacity(0.2), location: 0.08),
            .init(color: .black.opacity(0.15), location: 0.25),
            .init(color: .clear, location: 1),
          ],
          startPoint: .leading,
          endPoint: .trailing
        )
        .frame(width: 24)
        .mask(RoundedRectangle(cornerRadius: 2))
      }
      .overlay(alignment: .leading) {
        // Spine edge and fold contrast
        HStack(spacing: 0) {
          Color.black.opacity(0.2)
            .frame(width: 1)
          Color.white.opacity(0.3)
            .frame(width: 2)
          Color.black.opacity(0.35)
            .frame(width: 2)
        }
        .mask(RoundedRectangle(cornerRadius: 2))
      }
  }
}

extension View {
  @ViewBuilder
  func bookSpine(_ show: Bool = true) -> some View {
    if show {
      modifier(BookSpineModifier())
    } else {
      self
    }
  }
}
