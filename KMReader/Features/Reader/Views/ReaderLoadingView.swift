//
// ReaderLoadingView.swift
//
//

import SwiftUI

struct ReaderLoadingView: View {
  let title: String
  let detail: String?
  let progress: Double?

  private var normalizedProgress: Double? {
    progress.map { min(max($0, 0), 1) }
  }

  private var showsProgress: Bool {
    normalizedProgress != nil
  }

  private var progressText: String {
    (normalizedProgress ?? 0).formatted(.percent.precision(.fractionLength(0)))
  }

  private var numericProgress: Double {
    normalizedProgress ?? 0
  }

  var body: some View {
    VStack(spacing: 24) {
      ZStack {
        // Background Ring
        Circle()
          .stroke(Color.primary.opacity(0.05), lineWidth: 4)
          .frame(width: 64, height: 64)

        // Determinate Progress Ring
        Circle()
          .trim(from: 0, to: normalizedProgress ?? 0)
          .stroke(
            LinearGradient(
              colors: [.accentColor, .accentColor.opacity(0.7)],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            ),
            style: StrokeStyle(lineWidth: 4, lineCap: .round)
          )
          .frame(width: 64, height: 64)
          .rotationEffect(.degrees(-90))
          .opacity(showsProgress ? 1 : 0)
          .animation(.easeOut(duration: 0.16), value: normalizedProgress)

        Text(progressText)
          .font(.system(.subheadline, design: .rounded).bold())
          .monospacedDigit()
          .contentTransition(.numericText(value: numericProgress))
          .animation(.easeOut(duration: 0.16), value: numericProgress)
          .opacity(showsProgress ? 1 : 0)
          .accessibilityHidden(!showsProgress)

        LoadingIcon()
          .opacity(showsProgress ? 0 : 1)
          .accessibilityHidden(showsProgress)
      }
      .padding(.top, 8)

      VStack(spacing: 8) {
        Text(title)
          .font(.headline)
          .foregroundStyle(.primary)

        Text(detail ?? " ")
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
          .frame(maxWidth: 280)
          .opacity(detail == nil ? 0 : 1)
          .accessibilityHidden(detail == nil)
      }
    }
    .padding(.vertical, 32)
    .padding(.horizontal, 40)
    .background {
      RoundedRectangle(cornerRadius: 28, style: .continuous)
        .fill(.ultraThinMaterial)
        .overlay {
          RoundedRectangle(cornerRadius: 28, style: .continuous)
            .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
        }
    }
    .shadow(color: Color.black.opacity(0.12), radius: 30, x: 0, y: 15)
  }
}

#Preview {
  ZStack {
    Color.gray.opacity(0.2).ignoresSafeArea()
    ReaderLoadingView(
      title: "Downloading book...",
      detail: "45% · 12.4 MB / 28.5 MB",
      progress: 0.45
    )
  }
}
