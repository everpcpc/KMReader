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

  @AppStorage("themeColorHex") private var themeColor: ThemeColor = .orange

  init(count: Int, size: CGFloat = 14) {
    self.count = count
    self.size = size
  }

  var body: some View {
    Text("\(count)")
      .font(.system(size: size).weight(.bold))
      .foregroundColor(.white)
      .padding(.horizontal, 4)
      .padding(.vertical, 2)
      .background(themeColor.color)
      .clipShape(Capsule())
      .padding(4)
  }
}
