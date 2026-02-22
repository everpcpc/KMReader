//
// CardOverlayTextStack.swift
//
//

import SwiftUI

struct CardOverlayTextStack<Detail: View, Progress: View>: View {
  let title: String
  let titleLeadingSystemImage: String?
  let subtitle: String?
  let titleLineLimit: Int
  let style: CardOverlayTextStyle
  let spacing: CGFloat
  let detail: Detail
  let progress: Progress

  init(
    title: String,
    titleLeadingSystemImage: String? = nil,
    subtitle: String? = nil,
    titleLineLimit: Int = 1,
    style: CardOverlayTextStyle = .standard,
    spacing: CGFloat = 4,
    @ViewBuilder detail: () -> Detail,
    @ViewBuilder progress: () -> Progress
  ) {
    self.title = title
    self.titleLeadingSystemImage = titleLeadingSystemImage
    self.subtitle = subtitle
    self.titleLineLimit = titleLineLimit
    self.style = style
    self.spacing = spacing
    self.detail = detail()
    self.progress = progress()
  }

  var body: some View {
    VStack(alignment: .leading, spacing: spacing) {
      if let subtitle = subtitle {
        Text(subtitle)
          .cardOverlaySubtitle(style)
          .lineLimit(1)
      }

      if let titleLeadingSystemImage {
        HStack(spacing: 4) {
          Image(systemName: titleLeadingSystemImage)
          Text(title)
            .lineLimit(titleLineLimit)
        }
        .cardOverlayTitle(style)
      } else {
        Text(title)
          .cardOverlayTitle(style)
          .lineLimit(titleLineLimit)
      }

      detail
        .cardOverlayDetail(style)

      progress
    }
  }
}

extension CardOverlayTextStack where Progress == EmptyView {
  init(
    title: String,
    titleLeadingSystemImage: String? = nil,
    subtitle: String? = nil,
    titleLineLimit: Int = 1,
    style: CardOverlayTextStyle = .standard,
    spacing: CGFloat = 4,
    @ViewBuilder detail: () -> Detail
  ) {
    self.init(
      title: title,
      titleLeadingSystemImage: titleLeadingSystemImage,
      subtitle: subtitle,
      titleLineLimit: titleLineLimit,
      style: style,
      spacing: spacing,
      detail: detail
    ) {
      EmptyView()
    }
  }
}
