//
//  ReaderLoadingView.swift
//  KMReader
//

import SwiftUI

struct ReaderLoadingView: View {
  let title: String
  let detail: String?
  let progress: Double?

  var body: some View {
    VStack(spacing: 24) {
      ZStack {
        // Background Ring
        Circle()
          .stroke(Color.primary.opacity(0.05), lineWidth: 4)
          .frame(width: 64, height: 64)

        if let progress = progress, progress > 0 {
          // Determinate Progress Ring
          Circle()
            .trim(from: 0, to: progress)
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
            .animation(.spring(duration: 0.6, bounce: 0.3), value: progress)

          Text("\(Int(progress * 100))")
            .font(.system(.subheadline, design: .rounded).bold())
            .monospacedDigit()
            + Text("%")
            .font(.system(.caption2, design: .rounded).bold())
            .foregroundStyle(.secondary)
        } else {
          // Indeterminate State
          LoadingIcon()
        }
      }
      .padding(.top, 8)

      VStack(spacing: 8) {
        Text(title)
          .font(.headline)
          .foregroundStyle(.primary)

        if let detail = detail {
          Text(detail)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: 280)
        }
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
    .transition(.opacity.combined(with: .scale(scale: 0.95)))
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
