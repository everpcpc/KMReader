//
//  UnreadCountBadge.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct UnreadCountBadge: View {
  let count: Int
  let size: CGFloat

  #if os(tvOS)
    static let defaultSize: CGFloat = 24
    private let padding: CGFloat = 6
  #else
    static let defaultSize: CGFloat = 12
    private let padding: CGFloat = 3
  #endif

  init(count: Int, size: CGFloat = defaultSize) {
    self.count = count
    self.size = size
  }

  var body: some View {
    Text("\(count)")
      .font(.system(size: size, weight: .semibold))
      .foregroundColor(.white)
      .padding(.horizontal, padding * 2)
      .padding(.vertical, padding)
      .background(Color.accentColor)
      .clipShape(Capsule())
      .overlay(Capsule().stroke(PlatformHelper.systemBackgroundColor, lineWidth: 2))
      .offset(x: padding * 2 + 1, y: -(padding + size / 2 + 1))
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
      .fill(Color.accentColor)
      .frame(width: size, height: size)
      .overlay(Capsule().stroke(PlatformHelper.systemBackgroundColor, lineWidth: 2))
      .offset(x: size / 2, y: -size / 2)
  }
}

#Preview {
  HStack(spacing: 15) {

    VStack {
      ZStack(alignment: .topTrailing) {
        Rectangle()
          .fill(Color.gray.opacity(0.3))
          .aspectRatio(0.7, contentMode: .fit)
          .cornerRadius(8)
          .overlay(
            Image(systemName: "photo")
              .foregroundColor(.gray)
          )

        UnreadCountBadge(count: 29)
        // UnreadIndicator()
      }
    }
  }
  .padding()
  .background(Color(UIColor.systemGroupedBackground))
}
