//
//  AdaptiveButtonStyle.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

enum AdaptiveButtonStyleType {
  case bordered
  case borderedProminent
  case plain
  case borderless
}

extension View {
  @ViewBuilder
  func adaptiveButtonStyle(_ style: AdaptiveButtonStyleType) -> some View {
    if #available(iOS 26.0, macOS 26.0, tvOS 26.0, *) {
      switch style {
      case .bordered:
        self.buttonStyle(.glass)
      case .borderedProminent:
        self.buttonStyle(.glassProminent)
      case .plain:
        self.buttonStyle(.glass)
      case .borderless:
        self.buttonStyle(.glass)
      }
    } else {
      #if os(tvOS)
        self.buttonStyle(.plain)
      #else
        switch style {
        case .bordered:
          self.buttonStyle(.bordered)
        case .borderedProminent:
          self.buttonStyle(.borderedProminent)
        case .plain:
          self.buttonStyle(.plain)
        case .borderless:
          self.buttonStyle(.borderless)
        }
      #endif
    }
  }
}
