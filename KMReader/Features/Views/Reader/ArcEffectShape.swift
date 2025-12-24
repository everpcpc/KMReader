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

    let maxWidth: CGFloat = 80
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
  let readingDirection: ReadingDirection
  let themeColor: Color

  private var isLeading: Bool {
    readingDirection == .rtl
  }

  private var isVertical: Bool {
    readingDirection == .vertical || readingDirection == .webtoon
  }

  var body: some View {
    GeometryReader { geometry in
      ZStack {
        if isVertical {
          VerticalArcEffectShape(progress: progress)
            .fill(
              LinearGradient(
                gradient: Gradient(colors: [
                  themeColor.opacity(0.6),
                  themeColor.opacity(0.3),
                  themeColor.opacity(0.0),
                ]),
                startPoint: .bottom,
                endPoint: .top
              )
            )
            .shadow(color: themeColor.opacity(0.4), radius: 20, x: 0, y: 0)
        } else {
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
        }

        if progress > 0.1 {
          let maxWidth: CGFloat = 80
          let currentWidth = maxWidth * progress

          if isVertical {
            let arrowY = geometry.size.height - currentWidth / 4
            Image(systemName: "arrow.up")
              .font(.system(size: 24, weight: .bold))
              .foregroundColor(.white)
              .opacity(Double(progress))
              .position(x: geometry.size.width / 2, y: arrowY)
          } else {
            let arrowX = isLeading ? (currentWidth / 4) : (geometry.size.width - currentWidth / 4)
            Image(systemName: isLeading ? "arrow.left" : "arrow.right")
              .font(.system(size: 24, weight: .bold))
              .foregroundColor(.white)
              .opacity(Double(progress))
              .position(x: arrowX, y: geometry.size.height / 2)
          }
        }
      }
    }
  }
}

struct VerticalArcEffectShape: Shape {
  var progress: CGFloat

  var animatableData: CGFloat {
    get { progress }
    set { progress = newValue }
  }

  func path(in rect: CGRect) -> Path {
    var path = Path()

    let maxHeight: CGFloat = 80
    let height = maxHeight * progress

    path.move(to: CGPoint(x: 0, y: rect.height))
    path.addQuadCurve(
      to: CGPoint(x: rect.width, y: rect.height),
      control: CGPoint(x: rect.width / 2, y: rect.height - height)
    )
    path.addLine(to: CGPoint(x: 0, y: rect.height))

    return path
  }
}
