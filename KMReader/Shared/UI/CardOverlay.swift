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
    private let background: Color = .orange
    private let padding: CGFloat = 6
  #else
    static let defaultSize: CGFloat = 12
    private let background: Color = .accentColor
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
      .background(background)
      .clipShape(Capsule())
      #if !os(tvOS)
        .overlay(Capsule().stroke(PlatformHelper.systemBackgroundColor, lineWidth: 2))
      #endif
      .offset(x: padding * 2, y: -(padding + size / 2))
  }
}

struct UnreadIndicator: View {
  let size: CGFloat

  #if os(tvOS)
    static let defaultSize: CGFloat = 24
    private let background: Color = .orange
  #else
    static let defaultSize: CGFloat = 12
    private let background: Color = .accentColor
  #endif

  init(size: CGFloat = defaultSize) {
    self.size = size
  }

  var body: some View {
    Circle()
      .fill(background)
      .frame(width: size, height: size)
      #if !os(tvOS)
        .overlay(Capsule().stroke(PlatformHelper.systemBackgroundColor, lineWidth: 2))
      #endif
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
}
