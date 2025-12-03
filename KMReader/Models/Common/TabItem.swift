//
//  TabItem.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

enum TabItem: String, CaseIterable, Hashable {
  case home = "home"
  case browse = "browse"
  #if !os(macOS)
    case settings = "settings"
  #endif

  var title: String {
    switch self {
    case .home:
      return "Home"
    case .browse:
      return "Browse"
    #if !os(macOS)
      case .settings:
        return "Settings"
    #endif
    }
  }

  var icon: String {
    switch self {
    case .home:
      return "house"
    case .browse:
      return "books.vertical"
    #if !os(macOS)
      case .settings:
        return "gearshape"
    #endif
    }
  }

  var label: some View {
    Label(title, systemImage: icon)
  }

  @ViewBuilder
  var content: some View {
    switch self {
    case .home:
      DashboardView()
    case .browse:
      BrowseView()
    #if !os(macOS)
      case .settings:
        SettingsView()
    #endif
    }
  }
}
