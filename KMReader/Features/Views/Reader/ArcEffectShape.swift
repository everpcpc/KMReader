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

  private let maxArcWidth: CGFloat = 80

  private var isLeading: Bool {
    readingDirection == .rtl
  }

  private var isVertical: Bool {
    readingDirection == .vertical || readingDirection == .webtoon
  }

  private var currentArcWidth: CGFloat {
    maxArcWidth * progress
  }

  private var arrowSize: CGFloat {
    24 * progress
  }

  private var showArrow: Bool {
    progress > 0.1
  }

  var body: some View {
    GeometryReader { geometry in
      ZStack {
        if isVertical {
          VerticalArcEffectShape(progress: progress)
            .fill(
              LinearGradient(
                gradient: Gradient(colors: [
                  Color.accentColor.opacity(0.6),
                  Color.accentColor.opacity(0.3),
                  Color.accentColor.opacity(0.0),
                ]),
                startPoint: .bottom,
                endPoint: .top
              )
            )
            .shadow(color: Color.accentColor.opacity(0.4), radius: 20, x: 0, y: 0)
        } else {
          ArcEffectShape(progress: progress, isLeading: isLeading)
            .fill(
              LinearGradient(
                gradient: Gradient(colors: [
                  Color.accentColor.opacity(0.6),
                  Color.accentColor.opacity(0.3),
                  Color.accentColor.opacity(0.0),
                ]),
                startPoint: isLeading ? .leading : .trailing,
                endPoint: isLeading ? .trailing : .leading
              )
            )
            .shadow(color: Color.accentColor.opacity(0.4), radius: 20, x: 0, y: 0)
        }

        if showArrow {
          if isVertical {
            Image(systemName: "arrow.up")
              .font(.system(size: arrowSize, weight: .bold))
              .foregroundColor(.white)
              .opacity(Double(progress))
              .position(x: geometry.size.width / 2, y: geometry.size.height - currentArcWidth / 4)
          } else {
            Image(systemName: isLeading ? "arrow.left" : "arrow.right")
              .font(.system(size: arrowSize, weight: .bold))
              .foregroundColor(.white)
              .opacity(Double(progress))
              .position(
                x: isLeading ? (currentArcWidth / 4) : (geometry.size.width - currentArcWidth / 4),
                y: geometry.size.height / 2
              )
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
