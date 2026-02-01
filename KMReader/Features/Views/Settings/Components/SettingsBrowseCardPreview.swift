//
//  SettingsBrowseCardPreview.swift
//  KMReader
//
//  Created by Komga iOS Client
//

import SwiftUI

struct SettingsBrowseCardPreview: View {
  let title: String
  let subtitle: String?
  let detail: String
  let unreadCount: Int?
  let showUnreadDot: Bool
  let progress: Double?

  @AppStorage("coverOnlyCards") private var coverOnlyCards: Bool = false
  @AppStorage("showBookCardSeriesTitle") private var showBookCardSeriesTitle: Bool = true
  @AppStorage("thumbnailPreserveAspectRatio") private var thumbnailPreserveAspectRatio: Bool = true
  @AppStorage("thumbnailShowShadow") private var thumbnailShowShadow: Bool = true
  @AppStorage("thumbnailShowUnreadIndicator") private var thumbnailShowUnreadIndicator: Bool = true
  @AppStorage("thumbnailShowProgressBar") private var thumbnailShowProgressBar: Bool = true

  private let cornerRadius: CGFloat = 8
  private let imageCornerRadius: CGFloat = 6
  private let coverRatio: CGFloat = 1 / 1.414
  private let animation: Animation = .default

  @State private var imageRatio: CGFloat = CGFloat.random(in: 0.5...2.0)

  init(
    title: String,
    subtitle: String? = nil,
    detail: String,
    unreadCount: Int? = nil,
    showUnreadDot: Bool = false,
    progress: Double? = nil
  ) {
    self.title = title
    self.subtitle = subtitle
    self.detail = detail
    self.unreadCount = unreadCount
    self.showUnreadDot = showUnreadDot
    self.progress = progress
  }

  private var shouldShowProgressBar: Bool {
    guard let progress = progress else { return false }
    return progress > 0 && progress < 1 && thumbnailShowProgressBar
  }

  private var shouldShowUnreadDot: Bool {
    showUnreadDot && thumbnailShowUnreadIndicator
  }

  private var shouldShowUnreadBadge: Bool {
    unreadCount != nil && thumbnailShowUnreadIndicator
  }

  private var spacing: CGFloat {
    shouldShowProgressBar ? 4 : 12
  }

  private var imageFill: LinearGradient {
    LinearGradient(
      colors: [Color(white: 0.88), Color(white: 0.78)],
      startPoint: .topLeading,
      endPoint: .bottomTrailing
    )
  }

  private var effectiveShadowStyle: ShadowStyle {
    thumbnailShowShadow ? .platform : .none
  }

  var body: some View {
    VStack(alignment: .leading, spacing: spacing) {
      coverView

      if shouldShowProgressBar, let progress = progress {
        ReadingProgressBar(progress: progress, type: .card)
      }

      if !coverOnlyCards {
        VStack(alignment: .leading, spacing: 4) {
          if let subtitle = subtitle, showBookCardSeriesTitle {
            Text(subtitle)
              .font(.caption)
              .foregroundColor(.secondary)
              .lineLimit(1)
          }

          Text(title)
            .lineLimit(1)

          Text(detail)
            .font(.caption)
            .foregroundColor(.secondary)
            .lineLimit(1)
        }
        .font(.footnote)
      }
    }
    .frame(maxHeight: .infinity, alignment: .top)
    .animation(animation, value: coverOnlyCards)
    .animation(animation, value: showBookCardSeriesTitle)
    .animation(animation, value: thumbnailPreserveAspectRatio)
    .animation(animation, value: thumbnailShowShadow)
    .animation(animation, value: thumbnailShowUnreadIndicator)
    .animation(animation, value: thumbnailShowProgressBar)
  }

  private var coverView: some View {
    ZStack {
      Color.clear

      if thumbnailPreserveAspectRatio {
        imageCard
          .aspectRatio(imageRatio, contentMode: .fit)
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
      } else {
        imageCard
      }
    }
    .aspectRatio(coverRatio, contentMode: .fit)
  }

  private var imageCard: some View {
    RoundedRectangle(cornerRadius: imageCornerRadius)
      .fill(imageFill)
      .overlay { imageBorderOverlay }
      .shadowStyle(effectiveShadowStyle, cornerRadius: imageCornerRadius)
      .overlay(alignment: .topTrailing) {
        if shouldShowUnreadBadge, let unreadCount = unreadCount {
          UnreadCountBadge(count: unreadCount)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        } else if shouldShowUnreadDot {
          UnreadIndicator()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        }
      }
  }

  @ViewBuilder
  private var imageBorderOverlay: some View {
    if !thumbnailShowShadow {
      RoundedRectangle(cornerRadius: imageCornerRadius)
        .stroke(Color.primary.opacity(0.15), lineWidth: 0.5)
    }
  }
}
