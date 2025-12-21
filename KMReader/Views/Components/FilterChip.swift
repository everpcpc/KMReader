//
//  FilterChip.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct FilterChip: View {
  let label: String
  let systemImage: String
  var variant: FilterChipVariant = .normal

  @Binding var openSheet: Bool

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
    .adaptiveButtonStyle(.bordered)
    .controlSize(.mini)
    .tint(variant == .negative ? .red : .accentColor)
  }
}

enum FilterChipVariant {
  case normal
  case negative
}
