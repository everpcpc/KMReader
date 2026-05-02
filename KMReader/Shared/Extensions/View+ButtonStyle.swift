//
// View+ButtonStyle.swift
//
//

import SwiftUI

enum AdaptiveButtonStyleType {
  case borderedProminent
  case bordered
  case borderless
  case plain
}

extension View {
  @ViewBuilder
  func adaptiveButtonStyle(_ style: AdaptiveButtonStyleType) -> some View {
    if #available(iOS 26.0, macOS 26.0, tvOS 26.0, *) {
      switch style {
      case .borderedProminent:
        #if os(tvOS)
          self.buttonStyle(.glass)
        #else
          self.buttonStyle(.glassProminent)
        #endif
      case .bordered:
        self.buttonStyle(.glass)
      case .borderless:
        self.buttonStyle(.glass)
      case .plain:
        #if os(tvOS)
          self.buttonStyle(.card)
        #elseif os(iOS)
          self.buttonStyle(.squish).hoverEffect(.lift)
        #elseif os(macOS)
          self.buttonStyle(.squish).macHoverEffect()
        #else
          self.buttonStyle(.plain)
        #endif
      }
    } else {
      switch style {
      case .borderedProminent:
        self.buttonStyle(.borderedProminent)
      case .bordered:
        self.buttonStyle(.bordered)
      case .borderless:
        self.buttonStyle(.borderless)
      case .plain:
        #if os(tvOS)
          self.buttonStyle(.card)
        #elseif os(iOS)
          self.buttonStyle(.squish).hoverEffect(.lift)
        #elseif os(macOS)
          self.buttonStyle(.squish).macHoverEffect()
        #else
          self.buttonStyle(.plain)
        #endif
      }
    }
  }
}
