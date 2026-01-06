//
//  TabItem.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

enum TabItem: Hashable, Identifiable {
  case home
  case browse
  case settings

  var id: String {
    switch self {
    case .home: return "home"
    case .browse: return "browse"
    case .settings: return "settings"
    }
  }

  var title: String {
    switch self {
    case .home:
      return String(localized: "tab.home")
    case .browse:
      return String(localized: "tab.browse")
    case .settings:
      return String(localized: "tab.settings")
    }
  }

  var icon: String {
    switch self {
    case .home:
      return "house"
    case .browse:
      return "books.vertical"
    case .settings:
      return "gearshape"
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
      MainBrowseView()
    case .settings:
      SettingsView()
    }
  }
}
