//
// FilterChip.swift
//
//

import SwiftUI

struct FilterChip: View {
  let label: String
  let systemImage: String
  var variant: FilterChipVariant = .normal

  @Binding var openSheet: Bool

  private var buttonStyle: AdaptiveButtonStyleType {
    switch variant {
    case .normal:
      return .bordered
    case .preset:
      return .borderedProminent
    case .negative:
      return .bordered
    }
  }

  private var buttonColor: Color {
    switch variant {
    case .normal:
      return .accentColor
    case .preset:
      return .accentColor
    case .negative:
      return .red
    }
  }

  var body: some View {
    Button {
      openSheet = true
    } label: {
      HStack(spacing: 4) {
        Image(systemName: systemImage)
          .font(.caption2)
        Text(label)
          .font(.caption)
          .fontWeight(.medium)
      }
    }
    .fixedSize()
    .adaptiveButtonStyle(buttonStyle)
    .optimizedControlSize()
    .tint(buttonColor)
  }
}

enum FilterChipVariant {
  case normal
  case preset
  case negative
}
