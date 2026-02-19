//
// LockToggleModifier.swift
//
//

import SwiftUI

struct LockToggleModifier: ViewModifier {
  @Binding var isLocked: Bool
  let alignment: VerticalAlignment

  func body(content: Content) -> some View {
    HStack(alignment: alignment, spacing: 4) {
      Button(action: { toggle() }) {
        Image(systemName: isLocked ? "lock.circle.fill" : "lock.circle.dotted")
          .contentTransition(.symbolEffect(.replace, options: .nonRepeating))
          .foregroundColor(isLocked ? .red : .secondary)
          .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .padding(.horizontal, 4)

      content
    }
  }

  private func toggle() {
    isLocked.toggle()
  }
}

extension View {
  func lockToggle(isLocked: Binding<Bool>, alignment: VerticalAlignment = .center) -> some View {
    modifier(LockToggleModifier(isLocked: isLocked, alignment: alignment))
  }
}
