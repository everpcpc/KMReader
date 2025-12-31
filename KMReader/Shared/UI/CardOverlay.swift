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
    private let padding: CGFloat = 8
  #else
    static let defaultSize: CGFloat = 12
    private let padding: CGFloat = 4
  #endif

  init(count: Int, size: CGFloat = defaultSize) {
    self.count = count
    self.size = size
  }

  var body: some View {
    Text("\(count)")
      .font(.system(size: size))
      .foregroundColor(.white)
      .padding(.horizontal, padding * 2)
      .padding(.vertical, padding)
      .background(Color.accentColor)
      .clipShape(Capsule())
      .shadow(color: .black.opacity(0.5), radius: 3, x: 0, y: 1)
      .padding(padding)
  }
}

struct UnreadIndicator: View {
  let size: CGFloat

  #if os(tvOS)
    static let defaultSize: CGFloat = 24
    private let padding: CGFloat = 8
  #else
    static let defaultSize: CGFloat = 12
    private let padding: CGFloat = 4
  #endif

  init(size: CGFloat = defaultSize) {
    self.size = size
  }

  var body: some View {
    Circle()
      .fill(Color.accentColor)
      .frame(width: size, height: size)
      .shadow(color: .black.opacity(0.5), radius: 3, x: 0, y: 1)
      .padding(padding)
  }
}
