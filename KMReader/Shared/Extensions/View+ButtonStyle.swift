//
//  AdaptiveButtonStyle.swift
//  Komga
//
//  Created by Komga iOS Client
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
          self.buttonStyle(.plain)
        #else
          self.buttonStyle(.squish)
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
          self.buttonStyle(.plain)
        #else
          self.buttonStyle(.squish)
        #endif
      }
    }
  }

  @ViewBuilder
  func glassEffectIfAvailable(enabled: Bool = true) -> some View {
    if enabled {
      if #available(iOS 26.0, macOS 26.0, tvOS 26.0, *) {
        self.glassEffect()
      } else {
        self
      }
    } else {
      self
    }
  }

  @ViewBuilder
  func glassEffectIfAvailable<S: Shape>(enabled: Bool = true, in shape: S) -> some View {
    if enabled {
      if #available(iOS 26.0, macOS 26.0, tvOS 26.0, *) {
        self.glassEffect(in: shape)
      } else {
        self
      }
    } else {
      self
    }
  }
}
