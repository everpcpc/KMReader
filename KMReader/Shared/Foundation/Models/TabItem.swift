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
  case offline
  case server
  case settings

  var id: String {
    switch self {
    case .home: return "home"
    case .browse: return "browse"
    case .offline: return "offline"
    case .server: return "server"
    case .settings: return "settings"
    }
  }

  var title: String {
    switch self {
    case .home:
      return String(localized: "tab.home")
    case .browse:
      return String(localized: "tab.browse")
    case .offline:
      return String(localized: "tab.offline")
    case .server:
      return String(localized: "tab.server")
    case .settings:
      return String(localized: "tab.settings")
    }
  }

  var icon: String {
    switch self {
    case .home:
      return "house"
    case .browse:
      return ContentIcon.browse
    case .offline:
      return "tray.and.arrow.down"
    case .server:
      return "server.rack"
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
    case .offline:
      OfflineView()
    case .server:
      ServerView()
    case .settings:
      SettingsView()
    }
  }
}
