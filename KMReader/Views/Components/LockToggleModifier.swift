//
//  LockToggleModifier.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct LockToggleModifier: ViewModifier {
  @Binding var isLocked: Bool
  let size: CGFloat

  func body(content: Content) -> some View {
    HStack(spacing: 0) {
      Button(action: { toggle() }) {
        Image(systemName: isLocked ? "lock.fill" : "lock.slash")
          .foregroundColor(isLocked ? .red : .secondary)
          .frame(width: size, height: size)
      }
      .buttonStyle(.plain)
      .padding(.horizontal, 8)

      content
    }
  }

  private func toggle() {
    withAnimation {
      isLocked.toggle()
    }
  }
}

extension View {
  func lockToggle(isLocked: Binding<Bool>, size: CGFloat = 14.0) -> some View {
    modifier(LockToggleModifier(isLocked: isLocked, size: size))
  }
}
