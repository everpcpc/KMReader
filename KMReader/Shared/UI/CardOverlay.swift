//
// CardOverlay.swift
//
//

import SwiftUI

struct UnreadCountBadge: View {
  let count: Int
  let size: CGFloat

  #if os(tvOS)
    static let defaultSize: CGFloat = 24
  #else
    static let defaultSize: CGFloat = 12
  #endif

  init(count: Int, size: CGFloat = defaultSize) {
    self.count = count
    self.size = size
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
          topTrailingRadius: 8,
          style: .continuous
        )
        .fill(Color(white: 0.12))
      )
  }
}

struct UnreadIndicator: View {
  let size: CGFloat

  #if os(tvOS)
    static let defaultSize: CGFloat = 24
  #else
    static let defaultSize: CGFloat = 12
  #endif

  init(size: CGFloat = defaultSize) {
    self.size = size
  }

  var body: some View {
    Circle()
      .fill(.white)
      .frame(width: size * 0.4, height: size * 0.4)
      .padding(size * 0.3)
      .background(
        UnevenRoundedRectangle(
          bottomLeadingRadius: size * 0.65,
          topTrailingRadius: 8,
          style: .continuous
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

        UnreadIndicator()
      }.frame(height: 160)
    }
  }
  .padding()
}
