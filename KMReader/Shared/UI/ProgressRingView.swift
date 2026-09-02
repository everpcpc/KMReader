//
// ProgressRingView.swift
//
//

import SwiftUI

/// Small circular progress indicator with the percentage centered inside.
struct ProgressRingView: View {
  let progress: Double
  var diameter: CGFloat = 28

  private var lineWidth: CGFloat {
    max(2.5, diameter * 0.1)
  }

  var body: some View {
    ZStack {
      Circle()
        .stroke(Color.secondary.opacity(0.25), lineWidth: lineWidth)
      Circle()
        .trim(from: 0, to: min(max(progress, 0), 1))
        .stroke(
          Color.accentColor,
          style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
        )
        .rotationEffect(.degrees(-90))
    }
    // Inset the strokes so their outer edge aligns with the view's frame
    // instead of overflowing it by half the line width.
    .padding(lineWidth / 2)
    .overlay {
      Text(min(max(progress, 0), 1), format: .percent.precision(.fractionLength(0)))
        .font(.system(size: diameter * 0.25, weight: .medium))
        .foregroundColor(.secondary)
        .minimumScaleFactor(0.6)
        .lineLimit(1)
    }
    .frame(width: diameter, height: diameter)
    .accessibilityLabel(Text("Progress"))
    .accessibilityValue(Text(min(max(progress, 0), 1), format: .percent.precision(.fractionLength(0))))
  }
}
