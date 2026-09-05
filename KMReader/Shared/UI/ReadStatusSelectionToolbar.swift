//
// ReadStatusSelectionToolbar.swift
//
//

import SwiftUI

/// Selection-mode toolbar for batch read status changes (mark read/unread).
struct ReadStatusSelectionToolbar: View {
  let selectedCount: Int
  let totalCount: Int
  let isSubmitting: Bool
  let onSelectAll: () -> Void
  let onMarkRead: () -> Void
  let onMarkUnread: () -> Void
  let onCancel: () -> Void

  var selectAllLabel: String {
    selectedCount == totalCount
      ? String(localized: "Deselect All")
      : String(localized: "Select All")
  }

  var selectAllImage: String {
    selectedCount == totalCount ? "checkmark.circle.fill" : "checkmark.circle"
  }

  var submitDisabled: Bool {
    isSubmitting || selectedCount == 0
  }

  var body: some View {
    HStack(spacing: 12) {
      Button {
        withAnimation {
          onSelectAll()
        }
      } label: {
        Label(selectAllLabel, systemImage: selectAllImage)
          .font(.footnote)
      }
      .adaptiveButtonStyle(.bordered)

      if selectedCount > 0 {
        Text("\(selectedCount) / \(totalCount)")
          .font(.footnote)
          .foregroundStyle(.secondary)
          .transition(.opacity)
      }

      Spacer()

      Button {
        onMarkRead()
      } label: {
        Image(systemName: "checkmark.circle")
      }
      .adaptiveButtonStyle(.borderedProminent)
      .disabled(submitDisabled)
      .accessibilityLabel(String(localized: "Mark Read"))

      Button {
        onMarkUnread()
      } label: {
        Image(systemName: "circle")
      }
      .adaptiveButtonStyle(.borderedProminent)
      .disabled(submitDisabled)
      .accessibilityLabel(String(localized: "Mark Unread"))

      Button(role: .cancel) {
        withAnimation {
          onCancel()
        }
      } label: {
        Image(systemName: "xmark")
      }
      .adaptiveButtonStyle(.bordered)
      .accessibilityLabel(String(localized: "Cancel"))
    }
    .transition(.opacity.combined(with: .move(edge: .top)))
  }
}
