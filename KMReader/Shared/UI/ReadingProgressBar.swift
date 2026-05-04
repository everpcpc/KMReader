//
// ReadingProgressBar.swift
//
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
  let showsShadow: Bool

  @ViewBuilder
  private var progressContent: some View {
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
          .animation(.easeInOut(duration: 0.2), value: progress)
      }
    }
  }

  init(progress: Double, type: ReadingProgressBarType) {
    self.progress = progress
    self.height = PlatformHelper.progressBarHeight
    switch type {
    case .reader:
      self.color = .white
      self.background = .secondary.opacity(0.4)
      self.showsShadow = true
    case .card:
      self.color = .accentColor
      self.background = .accentColor.opacity(0.4)
      self.showsShadow = false
    }
  }

  var body: some View {
    Group {
      if showsShadow {
        progressContent
          .shadow(color: .black.opacity(0.35), radius: 3, x: 0, y: 1)
      } else {
        progressContent
      }
    }
    .frame(height: height)
    .padding(height)
  }
}
