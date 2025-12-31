//
//  CardPlaceholder.swift
//  KMReader
//
//  Created by Komga iOS Client
//

import SwiftUI

/// Placeholder skeleton view for cards while data is loading
struct CardPlaceholder: View {
  let layout: BrowseLayoutMode

  @AppStorage("coverOnlyCards") private var coverOnlyCards: Bool = false

  private let ratio: CGFloat = 1.414

  var body: some View {
    switch layout {
    case .grid:
      VStack(alignment: .leading, spacing: 12) {
        RoundedRectangle(cornerRadius: 8)
          .fill(Color.gray.opacity(0.2))
          .aspectRatio(1 / ratio, contentMode: .fit)
        if !coverOnlyCards {
          VStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 8)
              .fill(Color.gray.opacity(0.2))
              .frame(height: 14)
            RoundedRectangle(cornerRadius: 8)
              .fill(Color.gray.opacity(0.15))
              .frame(height: 12)
              .frame(maxWidth: .infinity, alignment: .leading)
              .scaleEffect(x: 0.6, anchor: .leading)
          }
        }
      }
    case .list:
      RoundedRectangle(cornerRadius: 8)
        .fill(Color.gray.opacity(0.2))
        .frame(height: 60 * ratio)
    }
  }
}
