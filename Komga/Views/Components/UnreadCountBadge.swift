//
//  UnreadCountBadge.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct UnreadCountBadge: View {
  let count: Int
  @AppStorage("themeColorName") private var themeColorOption: ThemeColorOption = .orange

  var body: some View {
    Text("\(count)")
      .font(.caption.weight(.bold))
      .foregroundColor(.white)
      .padding(.horizontal, 8)
      .padding(.vertical, 4)
      .background(themeColorOption.color)
      .clipShape(Capsule())
  }
}

#Preview {
  UnreadCountBadge(count: 12)
}
