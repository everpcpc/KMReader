//
// CardOverlay.swift
//
//

import SwiftUI

struct UnreadCountBadge: View {
  let count: Int
  let size: CGFloat
  /// Must match the cover's corner radius so the badge arc overlaps the
  /// cover clip exactly; a different radius or corner style lets the cover
  /// bleed through at the top-right corner.
  let cornerRadius: CGFloat

  #if os(tvOS)
    static let defaultSize: CGFloat = 24
  #else
    static let defaultSize: CGFloat = 12
  #endif

  init(count: Int, size: CGFloat = defaultSize, cornerRadius: CGFloat = 8) {
    self.count = count
    self.size = size
    self.cornerRadius = cornerRadius
  }

  var body: some View {
    Text("\(count)")
      .font(.system(size: size, weight: .semibold, design: .rounded))
      .foregroundStyle(.white)
      .padding(.horizontal, size * 0.6)
      .padding(.vertical, size * 0.35)
      .background(
        UnevenRoundedRectangle(
          bottomLeadingRadius: size * 0.65,
          topTrailingRadius: cornerRadius,
          style: .circular
        )
        .fill(Color(white: 0.12))
      )
  }
}

struct CompletedIndicator: View {
  let size: CGFloat
  /// See UnreadCountBadge.cornerRadius.
  let cornerRadius: CGFloat

  #if os(tvOS)
    static let defaultSize: CGFloat = 24
  #else
    static let defaultSize: CGFloat = 12
  #endif

  init(size: CGFloat = defaultSize, cornerRadius: CGFloat = 8) {
    self.size = size
    self.cornerRadius = cornerRadius
  }

  var body: some View {
    Image(systemName: "checkmark")
      .font(.system(size: size * 0.5, weight: .bold))
      .foregroundStyle(.white)
      .padding(size * 0.3)
      .background(
        UnevenRoundedRectangle(
          bottomLeadingRadius: size * 0.65,
          topTrailingRadius: cornerRadius,
          style: .circular
        )
        .fill(Color(white: 0.12))
      )
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

        CompletedIndicator()
      }.frame(height: 160)
    }
  }
  .padding()
}
