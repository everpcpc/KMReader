//
//  CardOverlayTextStyle.swift
//  KMReader
//
//

import SwiftUI

struct CardOverlayTextStyle {
  let primaryColor: Color
  let secondaryColor: Color
  let titleFont: Font
  let subtitleFont: Font
  let detailFont: Font

  static let standard = CardOverlayTextStyle(
    primaryColor: .white,
    secondaryColor: Color.white.opacity(0.85),
    titleFont: .caption,
    subtitleFont: .caption2,
    detailFont: .caption2
  )
}

extension View {
  func cardOverlayTitle(_ style: CardOverlayTextStyle = .standard) -> some View {
    font(style.titleFont)
      .foregroundColor(style.primaryColor)
  }

  func cardOverlaySubtitle(_ style: CardOverlayTextStyle = .standard) -> some View {
    font(style.subtitleFont)
      .foregroundColor(style.secondaryColor)
  }

  func cardOverlayDetail(_ style: CardOverlayTextStyle = .standard) -> some View {
    font(style.detailFont)
      .foregroundColor(style.secondaryColor)
  }
}
