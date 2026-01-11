//
//  AppColorScheme.swift
//  KMReader
//
//  Created by Komga iOS Client
//

import SwiftUI

enum AppColorScheme: String, CaseIterable, Identifiable {
  case system
  case light
  case dark

  var id: String { self.rawValue }

  var label: String {
    switch self {
    case .system:
      return String(localized: "settings.appearance.colorScheme.system")
    case .light:
      return String(localized: "settings.appearance.colorScheme.light")
    case .dark:
      return String(localized: "settings.appearance.colorScheme.dark")
    }
  }

  var colorScheme: ColorScheme? {
    switch self {
    case .system:
      return nil
    case .light:
      return .light
    case .dark:
      return .dark
    }
  }
}
