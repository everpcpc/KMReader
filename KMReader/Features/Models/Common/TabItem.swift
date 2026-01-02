//
//  TabItem.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

enum TabItem: Hashable, Identifiable {
  case home
  case series
  case books
  case settings

  var id: String {
    switch self {
    case .home: return "home"
    case .series: return "series"
    case .books: return "books"
    case .settings: return "settings"
    }
  }

  var title: String {
    switch self {
    case .home:
      return String(localized: "tab.home")
    case .series:
      return String(localized: "tab.series")
    case .books:
      return String(localized: "tab.books")
    case .settings:
      return String(localized: "tab.settings")
    }
  }

  var icon: String {
    switch self {
    case .home:
      return "house"
    case .series:
      return "rectangle.stack"
    case .books:
      return "book"
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
    case .series:
      BrowseView(fixedContent: .series)
    case .books:
      BrowseView(fixedContent: .books)
    case .settings:
      SettingsView()
    }
  }
}
