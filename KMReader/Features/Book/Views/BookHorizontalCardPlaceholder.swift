//
// BookHorizontalCardPlaceholder.swift
//
//

import SwiftUI

/// Placeholder skeleton matching BookHorizontalCardView while data is loading
struct BookHorizontalCardPlaceholder: View {
  var coverWidth: CGFloat = 60

  private let cornerRadius: CGFloat = 8

  var body: some View {
    HStack(alignment: .top, spacing: 10) {
      RoundedRectangle(cornerRadius: cornerRadius)
        .fill(Color.gray.opacity(0.2))
        .aspectRatio(CoverAspectRatio.widthToHeight, contentMode: .fit)
        .frame(width: coverWidth)

      VStack(alignment: .leading, spacing: 2) {
        placeholderLine(textStyle: .caption, text: "Series Title", widthScale: 0.45, opacity: 0.18)
        placeholderLine(textStyle: .footnote, text: "Book Title", widthScale: 0.8, opacity: 0.2)

        Spacer(minLength: 2)

        placeholderLine(textStyle: .caption, text: "Page 42 • 36%", widthScale: 0.55, opacity: 0.15)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
    .padding(8)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background {
      RoundedRectangle(cornerRadius: 12)
        .fill(.regularMaterial)
        .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
    }
  }

  private func placeholderLine(
    textStyle: Font.TextStyle,
    text: String,
    widthScale: CGFloat,
    opacity: Double
  ) -> some View {
    Text(text)
      .font(Font.system(textStyle))
      .foregroundColor(.clear)
      .lineLimit(1)
      .frame(maxWidth: .infinity, alignment: .leading)
      .overlay(alignment: .leading) {
        RoundedRectangle(cornerRadius: cornerRadius)
          .fill(Color.gray.opacity(opacity))
          .frame(maxWidth: .infinity, alignment: .leading)
          .scaleEffect(x: widthScale, anchor: .leading)
      }
      .accessibilityHidden(true)
  }
}
