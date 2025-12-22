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

  init(progress: Double) {
    self.progress = progress
  }

  var body: some View {
    GeometryReader { geometry in
      ZStack(alignment: .leading) {
        Capsule()
          .fill(themeColor.color.opacity(0.4))
          .frame(height: progressBarHeight)

        Capsule()
          .fill(themeColor.color)
          .frame(
            width: max(geometry.size.width * progress, progress > 0 ? 4 : 0),
            height: progressBarHeight
          )
          .shadow(color: themeColor.color.opacity(0.6), radius: 2, x: 0, y: 0)
      }
    }
    .frame(height: progressBarHeight)
    .padding(progressBarHeight)
  }
}
