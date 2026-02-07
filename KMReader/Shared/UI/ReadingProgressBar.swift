//
//  ReadingProgressBar.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

enum ReadingProgressBarType {
  case reader
  case card
}

struct ReadingProgressBar: View {
  let progress: Double
  let height: CGFloat
  let color: Color
  let background: Color
  let glass: Bool

  init(progress: Double, type: ReadingProgressBarType) {
    self.progress = progress
    self.height = PlatformHelper.progressBarHeight
    switch type {
    case .reader:
      self.color = .white
      self.background = .secondary.opacity(0.4)
      self.glass = true
    case .card:
      self.color = .accentColor
      self.background = .accentColor.opacity(0.4)
      self.glass = false
    }
  }

  var body: some View {
    GeometryReader { geometry in
      ZStack(alignment: .leading) {
        Capsule()
          .fill(background)
          .frame(height: height)

        Capsule()
          .fill(color)
          .frame(
            width: max(geometry.size.width * progress, progress > 0 ? 4 : 0),
            height: height
          )
      }
      .glassEffectRegularIfAvailable(enabled: glass, in: Capsule())
    }
    .frame(height: height)
    .padding(height)
  }
}
