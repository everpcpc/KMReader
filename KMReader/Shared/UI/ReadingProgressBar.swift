//
//  ReadingProgressBar.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct ReadingProgressBar: View {
  let progress: Double

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
          .fill(.white.opacity(0.6))
          .frame(height: progressBarHeight)

        Capsule()
          .fill(Color.accentColor)
          .frame(
            width: max(geometry.size.width * progress, progress > 0 ? 4 : 0),
            height: progressBarHeight
          )
      }
      .shadow(color: .black.opacity(0.4), radius: 4, x: 0, y: 2)
    }
    .frame(height: progressBarHeight)
    .padding(progressBarHeight)
  }
}
