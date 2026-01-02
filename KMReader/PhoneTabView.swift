//
//  PhoneTabView.swift
//  KMReader
//

import SwiftUI

#if os(iOS)
  @available(iOS 18.0, *)
  struct PhoneTabView: View {
    @State private var selectedTab: TabItem = .home

    var body: some View {
      TabView(selection: $selectedTab) {
        Tab(TabItem.home.title, systemImage: TabItem.home.icon, value: TabItem.home) {
          NavigationStack {
            TabItem.home.content
              .handleNavigation()
          }
        }

        Tab(TabItem.series.title, systemImage: TabItem.series.icon, value: TabItem.series) {
          NavigationStack {
            TabItem.series.content
              .handleNavigation()
          }
        }

        Tab(TabItem.books.title, systemImage: TabItem.books.icon, value: TabItem.books) {
          NavigationStack {
            TabItem.books.content
              .handleNavigation()
          }
        }

        Tab(
          TabItem.settings.title, systemImage: TabItem.settings.icon, value: TabItem.settings,
          role: .search
        ) {
          NavigationStack {
            TabItem.settings.content
              .handleNavigation()
          }
        }
      }
      .tabBarMinimizeBehaviorIfAvailable()
    }
  }
#endif
