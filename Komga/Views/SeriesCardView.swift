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
      ThumbnailImage(url: thumbnailURL, width: cardWidth)
        .overlay(alignment: .topTrailing) {
          Group {
            if series.deleted {
              DeletedBadge()
            } else if series.booksUnreadCount > 0 {
              UnreadCountBadge(count: series.booksUnreadCount)
            }
          }
          .padding(4)
        }

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
