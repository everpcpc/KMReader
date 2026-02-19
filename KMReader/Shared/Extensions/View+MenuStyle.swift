//
// View+MenuStyle.swift
//
//

import SwiftUI

extension View {
  func appMenuStyle() -> some View {
    menuStyle(.button)
      .menuIndicator(.hidden)
  }
}
