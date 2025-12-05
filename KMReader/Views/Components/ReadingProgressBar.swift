//
//  ReadingProgressBar.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct ReadingProgressBar: View {
  let progress: Double
  @AppStorage("themeColorHex") private var themeColor: ThemeColor = .orange

  private var progressBarHeight: CGFloat {
    PlatformHelper.progressBarHeight
  }

  private var progressBarCornerRadius: CGFloat {
    progressBarHeight / 2
  }

  private var progressBarPadding: CGFloat {
    progressBarCornerRadius
  }

  var body: some View {
    GeometryReader { geometry in
      ZStack(alignment: .leading) {
        Rectangle()
          .fill(Color.white.opacity(0.3))
          .frame(height: progressBarHeight)
          .cornerRadius(progressBarCornerRadius)

        Rectangle()
          .fill(themeColor.color)
          .frame(
            width: max(geometry.size.width * progress, progress > 0 ? 4 : 0),
            height: progressBarHeight
          )
          .cornerRadius(progressBarCornerRadius)
          .shadow(color: themeColor.color.opacity(0.6), radius: 2, x: 0, y: 0)
      }
    }
    .frame(height: progressBarHeight)
    .padding(progressBarPadding)
  }
}
