//
// OfflineCoverSyncLibraryPickerRow.swift
//
//

import SwiftUI

struct OfflineCoverSyncLibraryPickerRow: View {
  let title: String
  let isSelected: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 12) {
        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
          .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
        Text(title)
          .foregroundStyle(.primary)
        Spacer()
      }
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
  }
}
