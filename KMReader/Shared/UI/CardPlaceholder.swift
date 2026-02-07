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
  let kind: CardPlaceholderKind

  @AppStorage("coverOnlyCards") private var coverOnlyCards: Bool = false
  @AppStorage("cardTextOverlayMode") private var cardTextOverlayMode: Bool = false

  private let ratio: CGFloat = 1.414
  private let cornerRadius: CGFloat = 8
  private let lineSpacing: CGFloat = 6

  private var listThumbnailWidth: CGFloat {
    switch kind {
    case .series:
      return 80
    case .book, .collection, .readList:
      return 60
    }
  }

  var body: some View {
    switch layout {
    case .grid:
      gridPlaceholder
    case .list:
      listPlaceholder
    }
  }

  private var gridPlaceholder: some View {
    VStack(alignment: .leading, spacing: 12) {
      gridThumbnail

      if !cardTextOverlayMode && !coverOnlyCards {
        VStack(alignment: .leading, spacing: lineSpacing) {
          ForEach(Array(gridLines.enumerated()), id: \.offset) { item in
            placeholderLine(
              textStyle: item.element.textStyle,
              text: item.element.text,
              widthScale: item.element.width,
              opacity: item.element.opacity
            )
          }
        }
      }
    }
  }

  private var gridThumbnail: some View {
    ZStack {
      RoundedRectangle(cornerRadius: cornerRadius)
        .fill(Color.gray.opacity(0.2))

      if cardTextOverlayMode {
        CardTextOverlay(cornerRadius: cornerRadius) {
          ForEach(Array(gridLines.enumerated()), id: \.offset) { item in
            placeholderLine(
              textStyle: item.element.textStyle,
              text: item.element.text,
              widthScale: item.element.width,
              opacity: item.element.opacity
            )
          }
        }
      }
    }
    .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    .aspectRatio(1 / ratio, contentMode: .fit)
  }

  private var listPlaceholder: some View {
    HStack(alignment: .top, spacing: 12) {
      RoundedRectangle(cornerRadius: cornerRadius)
        .fill(Color.gray.opacity(0.2))
        .frame(width: listThumbnailWidth)
        .aspectRatio(1 / ratio, contentMode: .fit)

      VStack(alignment: .leading, spacing: lineSpacing) {
        ForEach(Array(listLines.enumerated()), id: \.offset) { item in
          placeholderLine(
            textStyle: item.element.textStyle,
            text: item.element.text,
            widthScale: item.element.width,
            opacity: item.element.opacity
          )
        }
      }
    }
  }

  private var gridLines: [(textStyle: Font.TextStyle, text: String, width: CGFloat, opacity: Double)] {
    switch kind {
    case .book:
      return [
        (textStyle: .caption, text: "Series Title", width: 0.55, opacity: 0.18),
        (textStyle: .footnote, text: "1 - Book Title", width: 0.85, opacity: 0.2),
        (textStyle: .caption, text: "200 pages", width: 0.6, opacity: 0.15),
      ]
    case .series:
      return [
        (textStyle: .footnote, text: "Series Title", width: 0.8, opacity: 0.2),
        (textStyle: .caption, text: "12 books", width: 0.6, opacity: 0.15),
      ]
    case .collection:
      return [
        (textStyle: .footnote, text: "Collection Name", width: 0.75, opacity: 0.2),
        (textStyle: .footnote, text: "8 series", width: 0.5, opacity: 0.15),
      ]
    case .readList:
      return [
        (textStyle: .footnote, text: "Read List Name", width: 0.75, opacity: 0.2),
        (textStyle: .footnote, text: "12 books", width: 0.5, opacity: 0.15),
      ]
    }
  }

  private var listLines: [(textStyle: Font.TextStyle, text: String, width: CGFloat, opacity: Double)] {
    switch kind {
    case .book:
      return [
        (textStyle: .footnote, text: "Series Title", width: 0.55, opacity: 0.18),
        (textStyle: .body, text: "#12 - Book Title", width: 0.85, opacity: 0.2),
        (textStyle: .caption, text: "Last Updated", width: 0.6, opacity: 0.15),
        (textStyle: .footnote, text: "200 pages 120 MB", width: 0.7, opacity: 0.15),
      ]
    case .series:
      return [
        (textStyle: .callout, text: "Series Title", width: 0.85, opacity: 0.2),
        (textStyle: .footnote, text: "Ongoing", width: 0.5, opacity: 0.15),
        (textStyle: .caption, text: "Last Updated", width: 0.6, opacity: 0.15),
        (textStyle: .footnote, text: "12 books 3 unread", width: 0.75, opacity: 0.15),
      ]
    case .collection:
      return [
        (textStyle: .callout, text: "Collection Name", width: 0.8, opacity: 0.2),
        (textStyle: .footnote, text: "8 series", width: 0.5, opacity: 0.15),
        (textStyle: .caption, text: "Last Updated", width: 0.6, opacity: 0.15),
      ]
    case .readList:
      return [
        (textStyle: .callout, text: "Read List Name", width: 0.8, opacity: 0.2),
        (textStyle: .footnote, text: "12 books", width: 0.5, opacity: 0.15),
        (textStyle: .caption, text: "Last Updated", width: 0.6, opacity: 0.15),
        (textStyle: .caption, text: "Short summary", width: 0.75, opacity: 0.15),
      ]
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
