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
        self.buttonStyle(.glassProminent)
      case .bordered:
        self.buttonStyle(.glass)
      case .borderless:
        self.buttonStyle(.glass)
      case .plain:
        self.buttonStyle(.plain)
      }
    } else {
      #if os(tvOS)
        self.buttonStyle(.plain)
      #else
        switch style {
        case .borderedProminent:
          self.buttonStyle(.borderedProminent)
        case .bordered:
          self.buttonStyle(.bordered)
        case .borderless:
          self.buttonStyle(.borderless)
        case .plain:
          self.buttonStyle(.plain)
        }
      #endif
    }
  }
}
