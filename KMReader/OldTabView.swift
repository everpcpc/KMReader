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

      NavigationStack {
        TabItem.browse.content
          .handleNavigation()
      }
      .tabItem { TabItem.browse.label }

      NavigationStack {
        TabItem.settings.content
          .handleNavigation()
      }
      .tabItem { TabItem.settings.label }
    }
  }
}
