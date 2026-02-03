//
//  OldTabView.swift
//  KMReader
//

import SwiftUI

struct OldTabView: View {
  @State private var selectedTab: TabItem = .home

  var body: some View {
    TabView(selection: $selectedTab) {
      NavigationStack {
        TabItem.home.content
          .handleNavigation()
      }
      .tabItem { TabItem.home.label }
      .tag(TabItem.home)

      NavigationStack {
        TabItem.browse.content
          .handleNavigation()
      }
      .tabItem { TabItem.browse.label }
      .tag(TabItem.browse)

      NavigationStack {
        TabItem.offline.content
          .handleNavigation()
      }
      .tabItem { TabItem.offline.label }
      .tag(TabItem.offline)

      NavigationStack {
        TabItem.server.content
          .handleNavigation()
      }
      .tabItem { TabItem.server.label }
      .tag(TabItem.server)

      NavigationStack {
        TabItem.settings.content
          .handleNavigation()
      }
      .tabItem { TabItem.settings.label }
      .tag(TabItem.settings)
    }
  }
}
