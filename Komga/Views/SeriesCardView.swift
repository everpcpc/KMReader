//
//  SeriesCardView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct SeriesCardView: View {
  let series: Series
  let cardWidth: CGFloat
  let showTitle: Bool
  @AppStorage("themeColorName") private var themeColorOption: ThemeColorOption = .orange

  private var thumbnailURL: URL? {
    SeriesService.shared.getSeriesThumbnailURL(id: series.id)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      // Thumbnail
      ThumbnailImage(url: thumbnailURL)
        .frame(width: cardWidth, height: cardWidth * 1.3)
        .clipped()
        .cornerRadius(8)
        .overlay(alignment: .topTrailing) {
          if series.booksUnreadCount > 0 {
            Text("\(series.booksUnreadCount)")
              .font(.caption)
              .fontWeight(.bold)
              .foregroundColor(.white)
              .padding(.horizontal, 8)
              .padding(.vertical, 4)
              .background(themeColorOption.color)
              .clipShape(Capsule())
              .padding(4)
          }
        }

      // Series info
      VStack(alignment: .leading, spacing: 2) {
        if showTitle {
          Text(series.metadata.title)
            .font(.caption)
            .foregroundColor(.primary)
            .lineLimit(1)
        }
        Text("\(series.booksCount) books")
          .font(.caption2)
          .foregroundColor(.secondary)
      }
      .frame(width: cardWidth, alignment: .leading)
    }
  }
}
