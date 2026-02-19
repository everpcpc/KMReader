//
// CardOverlay.swift
//
//

import SwiftUI

struct UnreadCountBadge: View {
  let count: Int
  let size: CGFloat

  private var padding: CGFloat {
    size / 4
  }

  private var cornerRadius: CGFloat {
    size
  }

  #if os(tvOS)
    static let defaultSize: CGFloat = 24
    private let accentColor: Color = .orange
  #else
    static let defaultSize: CGFloat = 12
    private let accentColor: Color = .accentColor
  #endif

  private let accentOpacity: Double = 0.9
  private let borderOpacity: Double = 0.25

  private var badgeFill: LinearGradient {
    LinearGradient(
      colors: [accentColor.opacity(0.98), accentColor.opacity(accentOpacity)],
      startPoint: .top,
      endPoint: .bottom
    )
  }

  init(count: Int, size: CGFloat = defaultSize) {
    self.count = count
    self.size = size
  }

  var body: some View {
    Text("\(count)")
      .font(.system(size: size, weight: .semibold, design: .rounded))
      .foregroundColor(.white)
      .padding(.horizontal, padding * 2)
      .padding(.vertical, padding)
      .background {
        Capsule()
          .fill(badgeFill)
          .overlay {
            Capsule()
              .strokeBorder(.white.opacity(borderOpacity), lineWidth: 0.8)
          }
      }
      .floatingBadgeShadow(size: size, cornerRadius: cornerRadius)
      .padding(.top, padding)
      .padding(.trailing, padding)
  }
}

struct UnreadIndicator: View {
  let size: CGFloat

  private var padding: CGFloat {
    size / 4
  }

  private var cornerRadius: CGFloat {
    size / 2
  }

  #if os(tvOS)
    static let defaultSize: CGFloat = 24
    private let accentColor: Color = .orange
  #else
    static let defaultSize: CGFloat = 12
    private let accentColor: Color = .accentColor
  #endif

  private let accentOpacity: Double = 0.9
  private let borderOpacity: Double = 0.25

  private var badgeFill: LinearGradient {
    LinearGradient(
      colors: [accentColor.opacity(0.98), accentColor.opacity(accentOpacity)],
      startPoint: .top,
      endPoint: .bottom
    )
  }

  init(size: CGFloat = defaultSize) {
    self.size = size
  }

  var body: some View {
    Circle()
      .fill(badgeFill)
      .overlay {
        Circle()
          .strokeBorder(.white.opacity(borderOpacity), lineWidth: 0.8)
      }
      .frame(width: size, height: size)
      .floatingBadgeShadow(size: size, cornerRadius: cornerRadius)
      .padding(.top, padding)
      .padding(.trailing, padding)
  }
}

private struct FloatingBadgeShadowModifier: ViewModifier {
  let size: CGFloat
  let cornerRadius: CGFloat

  @Environment(\.colorScheme) private var colorScheme

  private var baseShadowColor: Color {
    colorScheme == .light ? .black.opacity(0.3) : .black.opacity(0.5)
  }

  private var highlightShadowColor: Color {
    colorScheme == .light ? .white.opacity(0.38) : .white.opacity(0.14)
  }

  private var baseShadowRadius: CGFloat {
    max(2, size * 0.3)
  }

  private var baseShadowYOffset: CGFloat {
    max(1, size * 0.2)
  }

  private var highlightShadowRadius: CGFloat {
    max(1, size * 0.12)
  }

  private var highlightShadowYOffset: CGFloat {
    -max(0.6, size * 0.08)
  }

  func body(content: Content) -> some View {
    content
      .background(
        ShadowPathView(
          color: baseShadowColor,
          radius: baseShadowRadius,
          x: 0,
          y: baseShadowYOffset,
          cornerRadius: cornerRadius
        )
      )
      .background(
        ShadowPathView(
          color: highlightShadowColor,
          radius: highlightShadowRadius,
          x: 0,
          y: highlightShadowYOffset,
          cornerRadius: cornerRadius
        )
      )
  }
}

extension View {
  fileprivate func floatingBadgeShadow(size: CGFloat, cornerRadius: CGFloat) -> some View {
    modifier(FloatingBadgeShadowModifier(size: size, cornerRadius: cornerRadius))
  }
}

#Preview {
  VStack {
    HStack {
      ZStack(alignment: .topTrailing) {
        Rectangle()
          .fill(Color.gray.opacity(0.3))
          .aspectRatio(0.7, contentMode: .fit)
          .cornerRadius(8)
          .overlay(
            Image(systemName: "photo")
              .foregroundColor(.gray)
          )

        UnreadCountBadge(count: 291)
      }.frame(height: 160)

      ZStack(alignment: .topTrailing) {
        Rectangle()
          .fill(Color.gray.opacity(0.3))
          .aspectRatio(0.7, contentMode: .fit)
          .cornerRadius(8)
          .overlay(
            Image(systemName: "photo")
              .foregroundColor(.gray)
          )

        UnreadIndicator()
      }.frame(height: 160)
    }
  }
  .padding()
}
