//
//  CardTextOverlay.swift
//  KMReader
//
//  Created by Komga iOS Client
//

import SwiftUI

struct CardTextOverlay<Content: View>: View {
  private let cornerRadius: CGFloat
  private let overlayHeightRatio: CGFloat
  private let horizontalPadding: CGFloat
  private let verticalPadding: CGFloat
  private let spacing: CGFloat
  private let content: Content

  init(
    cornerRadius: CGFloat = 8,
    overlayHeightRatio: CGFloat = 0.5,
    horizontalPadding: CGFloat = 6,
    verticalPadding: CGFloat = 4,
    spacing: CGFloat = 4,
    @ViewBuilder content: () -> Content
  ) {
    self.cornerRadius = cornerRadius
    self.overlayHeightRatio = overlayHeightRatio
    self.horizontalPadding = horizontalPadding
    self.verticalPadding = verticalPadding
    self.spacing = spacing
    self.content = content()
  }

  var body: some View {
    GeometryReader { proxy in
      let overlayHeight = proxy.size.height * overlayHeightRatio
      ZStack(alignment: .bottomLeading) {
        overlayBackground
          .frame(maxWidth: .infinity, maxHeight: .infinity)

        VStack(alignment: .leading, spacing: spacing) {
          content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, verticalPadding)
        .frame(height: overlayHeight, alignment: .bottomLeading)
        .frame(maxHeight: .infinity, alignment: .bottomLeading)
      }
    }
    .allowsHitTesting(false)
    .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
  }

  private var overlayBackground: some View {
    LinearGradient(
      stops: [
        .init(color: .clear, location: 0.0),
        .init(color: .clear, location: 0.5),
        .init(color: .black.opacity(0.2), location: 0.65),
        .init(color: .black.opacity(0.45), location: 0.8),
        .init(color: .black.opacity(0.88), location: 1.0),
      ],
      startPoint: .top,
      endPoint: .bottom
    )
  }
}
