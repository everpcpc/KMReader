//
//  CardOverlayTextStack.swift
//  KMReader
//
//  Created by Komga iOS Client
//

import SwiftUI

struct CardOverlayTextStack<Detail: View, Progress: View>: View {
  let title: String
  let subtitle: String?
  let titleLineLimit: Int
  let style: CardOverlayTextStyle
  let spacing: CGFloat
  let detail: Detail
  let progress: Progress

  init(
    title: String,
    subtitle: String? = nil,
    titleLineLimit: Int = 1,
    style: CardOverlayTextStyle = .standard,
    spacing: CGFloat = 4,
    @ViewBuilder detail: () -> Detail,
    @ViewBuilder progress: () -> Progress
  ) {
    self.title = title
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

      Text(title)
        .cardOverlayTitle(style)
        .lineLimit(titleLineLimit)

      detail
        .cardOverlayDetail(style)

      progress
    }
  }
}

extension CardOverlayTextStack where Progress == EmptyView {
  init(
    title: String,
    subtitle: String? = nil,
    titleLineLimit: Int = 1,
    style: CardOverlayTextStyle = .standard,
    spacing: CGFloat = 4,
    @ViewBuilder detail: () -> Detail
  ) {
    self.init(
      title: title,
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
