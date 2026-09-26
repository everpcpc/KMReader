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
  /// hoverEffect: pass false when the enclosing container applies its own
  /// pointer-hover feedback (e.g. horizontal cards lift as a whole).
  @ViewBuilder
  func adaptiveButtonStyle(_ style: AdaptiveButtonStyleType, hoverEffect: Bool = true) -> some View {
    if #available(iOS 26.0, macOS 26.0, tvOS 26.0, *) {
      switch style {
      case .borderedProminent:
        #if os(tvOS)
          self.buttonStyle(.glass)
        #else
          // Prominent styles don't auto-contrast the label against the tint;
          // the tint/foreground asset pair carries both appearances.
          self.buttonStyle(.glassProminent)
            .tint(Color.prominentButtonTint)
            .foregroundStyle(Color.prominentButtonForeground)
        #endif
      case .bordered:
        self.buttonStyle(.glass)
      case .borderless:
        self.buttonStyle(.glass)
      case .plain:
        self.plainAdaptiveButtonStyle(hoverEffect: hoverEffect)
      }
    } else {
      switch style {
      case .borderedProminent:
        self.buttonStyle(.borderedProminent)
          .tint(Color.prominentButtonTint)
          .foregroundStyle(Color.prominentButtonForeground)
      case .bordered:
        self.buttonStyle(.bordered)
      case .borderless:
        self.buttonStyle(.borderless)
      case .plain:
        self.plainAdaptiveButtonStyle(hoverEffect: hoverEffect)
      }
    }
  }

  @ViewBuilder
  private func plainAdaptiveButtonStyle(hoverEffect: Bool) -> some View {
    #if os(tvOS)
      self.buttonStyle(.card)
    #elseif os(iOS)
      if hoverEffect {
        self.buttonStyle(.squish).hoverEffect(.lift)
      } else {
        self.buttonStyle(.squish)
      }
    #elseif os(macOS)
      if hoverEffect {
        self.buttonStyle(.squish).macHoverEffect()
      } else {
        self.buttonStyle(.squish)
      }
    #else
      self.buttonStyle(.plain)
    #endif
  }
}
