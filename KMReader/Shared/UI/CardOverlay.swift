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

  private var padding: CGFloat {
    size / 4
  }

  #if os(tvOS)
    static let defaultSize: CGFloat = 24
    private let accentColor: Color = .orange
  #else
    static let defaultSize: CGFloat = 12
    private let accentColor: Color = .accentColor
  #endif

  private let accentOpacity: Double = 0.9

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
      .background(accentColor.opacity(accentOpacity), in: Capsule())
      .glassEffectIfAvailable(.clear, in: Capsule())
      .padding(.top, padding)
      .padding(.trailing, padding)
  }
}

struct UnreadIndicator: View {
  let size: CGFloat

  private var padding: CGFloat {
    size / 4
  }

  #if os(tvOS)
    static let defaultSize: CGFloat = 24
    private let accentColor: Color = .orange
  #else
    static let defaultSize: CGFloat = 12
    private let accentColor: Color = .accentColor
  #endif

  private let accentOpacity: Double = 0.9

  init(size: CGFloat = defaultSize) {
    self.size = size
  }

  var body: some View {
    Circle()
      .fill(accentColor.opacity(accentOpacity))
      .glassEffectIfAvailable(.clear, in: Circle())
      .frame(width: size, height: size)
      .padding(.top, padding)
      .padding(.trailing, padding)
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
