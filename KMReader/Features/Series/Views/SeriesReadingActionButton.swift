//
// SeriesReadingActionButton.swift
//
//

import SwiftUI

/// Inline primary continue-reading action shown below the series header block.
/// Rendered on every platform except iPhone on iOS 26.1+, where the system
/// tab bar bottom accessory takes over.
struct SeriesReadingActionButton: View {
  let caption: String
  let title: String
  let isResolving: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 10) {
        Image(systemName: "book.fill")
          .font(.callout)
          .foregroundStyle(Color.accentColor)

        VStack(alignment: .leading, spacing: 1) {
          Text(caption)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.primary)
            .lineLimit(1)
            .contentTransition(.opacity)

          Text(title)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .contentTransition(.opacity)
        }

        if isResolving {
          ProgressView()
            .controlSize(.small)
            .padding(.leading, 4)
        }
      }
      .padding(.horizontal, 4)
    }
    .adaptiveButtonStyle(.bordered)
    .buttonBorderShape(.capsule)
    .accessibilityLabel(Text("\(caption), \(title)"))
  }
}
