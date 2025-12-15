//
//  ArcEffectShape.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct ArcEffectShape: Shape {
  var progress: CGFloat
  var isLeading: Bool

  var animatableData: CGFloat {
    get { progress }
    set { progress = newValue }
  }

  func path(in rect: CGRect) -> Path {
    var path = Path()

    let maxWidth: CGFloat = 60
    let width = maxWidth * progress

    if isLeading {
      path.move(to: CGPoint(x: 0, y: 0))
      path.addQuadCurve(
        to: CGPoint(x: 0, y: rect.height),
        control: CGPoint(x: width, y: rect.height / 2)
      )
      path.addLine(to: CGPoint(x: 0, y: 0))
    } else {
      path.move(to: CGPoint(x: rect.width, y: 0))
      path.addQuadCurve(
        to: CGPoint(x: rect.width, y: rect.height),
        control: CGPoint(x: rect.width - width, y: rect.height / 2)
      )
      path.addLine(to: CGPoint(x: rect.width, y: 0))
    }

    return path
  }
}

struct ArcEffectView: View {
  let progress: CGFloat
  let isLeading: Bool
  let themeColor: Color

  var body: some View {
    ArcEffectShape(progress: progress, isLeading: isLeading)
      .fill(
        LinearGradient(
          gradient: Gradient(colors: [
            themeColor.opacity(0.6),
            themeColor.opacity(0.3),
            themeColor.opacity(0.0),
          ]),
          startPoint: isLeading ? .leading : .trailing,
          endPoint: isLeading ? .trailing : .leading
        )
      )
      .shadow(color: themeColor.opacity(0.4), radius: 20, x: 0, y: 0)
      .allowsHitTesting(false)
  }
}
