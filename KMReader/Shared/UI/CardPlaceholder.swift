//
//  CardPlaceholder.swift
//  KMReader
//
//  Created by Komga iOS Client
//

import SwiftUI

/// Placeholder skeleton view for cards while data is loading
struct CardPlaceholder: View {
  let cardWidth: CGFloat
  let layout: BrowseLayoutMode

  @AppStorage("coverOnlyCards") private var coverOnlyCards: Bool = false

  private let ratio: CGFloat = 1.414

  var body: some View {
    switch layout {
    case .grid:
      VStack(alignment: .leading, spacing: 12) {
        RoundedRectangle(cornerRadius: 8)
          .fill(Color.gray.opacity(0.2))
          .frame(width: cardWidth, height: cardWidth * ratio)
        if !coverOnlyCards {
          VStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 8)
              .fill(Color.gray.opacity(0.2))
              .frame(height: 14)
            RoundedRectangle(cornerRadius: 8)
              .fill(Color.gray.opacity(0.15))
              .frame(width: cardWidth * 0.6, height: 12)
          }
        }
      }
      .frame(width: cardWidth)
    case .list:
      RoundedRectangle(cornerRadius: 8)
        .fill(Color.gray.opacity(0.2))
        .frame(height: 60 * ratio)
    }
  }
}
