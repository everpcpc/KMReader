//
// SeriesReadingActionButton.swift
//
//

import SwiftUI

/// Inline primary continue-reading action shown below the series header block.
/// Rendered on every platform except iPhone on iOS 26.1+, where the system
/// tab bar bottom accessory takes over. The button hugs its content and
/// follows the action card's `detailHeroCentered` alignment.
struct SeriesReadingActionButton: View {
  let caption: String
  let title: String
  let isResolving: Bool
  let action: () -> Void

  @Environment(\.detailHeroCentered) private var heroCentered

  var body: some View {
    Button(action: action) {
      HStack(spacing: 10) {
        Image(systemName: "book.fill")
          .font(.callout)

        VStack(alignment: .leading, spacing: 1) {
          Text(caption)
            .font(.subheadline.weight(.semibold))
            .lineLimit(1)
            .contentTransition(.opacity)

          Text(title)
            .font(.caption)
            .opacity(0.85)
            .lineLimit(1)
            .contentTransition(.opacity)
        }

        if isResolving {
          ProgressView()
            .controlSize(.small)
            #if !os(tvOS)
              .tint(Color.prominentButtonForeground)
            #endif
            .padding(.leading, 4)
        }
      }
      .padding(.horizontal, 12)
    }
    .adaptiveButtonStyle(.borderedProminent)
    .buttonBorderShape(.capsule)
    .accessibilityLabel(Text("\(caption), \(title)"))
    .frame(maxWidth: .infinity, alignment: heroCentered ? .center : .leading)
  }
}
