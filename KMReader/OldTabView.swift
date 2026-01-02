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
        TabItem.series.content
          .handleNavigation()
      }
      .tabItem { TabItem.series.label }
      .tag(TabItem.series)

      NavigationStack {
        TabItem.books.content
          .handleNavigation()
      }
      .tabItem { TabItem.books.label }
      .tag(TabItem.books)

      NavigationStack {
        TabItem.settings.content
          .handleNavigation()
      }
      .tabItem { TabItem.settings.label }
      .tag(TabItem.settings)
    }
  }
}
