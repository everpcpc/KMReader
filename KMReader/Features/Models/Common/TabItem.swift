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
  case series
  case books
  case collections
  case readLists
  case settings

  var id: String {
    switch self {
    case .home: return "home"
    case .browse: return "browse"
    case .series: return "series"
    case .books: return "books"
    case .collections: return "collections"
    case .readLists: return "readlists"
    case .settings: return "settings"
    }
  }

  var title: String {
    switch self {
    case .home:
      return String(localized: "tab.home")
    case .browse:
      return String(localized: "tab.browse")
    case .series:
      return BrowseContentType.series.displayName
    case .books:
      return BrowseContentType.books.displayName
    case .collections:
      return BrowseContentType.collections.displayName
    case .readLists:
      return BrowseContentType.readlists.displayName
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
    case .series:
      return "rectangle.stack"
    case .books:
      return "book"
    case .collections:
      return "square.stack.3d.down.right"
    case .readLists:
      return "list.bullet.rectangle"
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
    case .series:
      BrowseView(fixedContent: .series)
    case .books:
      BrowseView(fixedContent: .books)
    case .collections:
      BrowseView(fixedContent: .collections)
    case .readLists:
      BrowseView(fixedContent: .readlists)
    case .settings:
      SettingsView()
    }
  }
}
