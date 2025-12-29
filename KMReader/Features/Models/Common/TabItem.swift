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
  case settings = "settings"

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
      BrowseView()
    case .settings:
      SettingsView()
    }
  }
}
