//
//  TVTabView.swift
//  KMReader
//

import SwiftUI

#if os(tvOS)
  @available(tvOS 18.0, *)
  struct TVTabView: View {
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
          TabItem.collections.title,
          systemImage: TabItem.collections.icon,
          value: TabItem.collections
        ) {
          NavigationStack {
            TabItem.collections.content
              .handleNavigation()
          }
        }

        Tab(
          TabItem.readLists.title,
          systemImage: TabItem.readLists.icon,
          value: TabItem.readLists
        ) {
          NavigationStack {
            TabItem.readLists.content
              .handleNavigation()
          }
        }

        TabSection(String(localized: "Settings")) {
          Tab(
            TabItem.settings.title, systemImage: TabItem.settings.icon, value: TabItem.settings
          ) {
            NavigationStack {
              TabItem.settings.content
                .handleNavigation()
            }
          }
        }
      }
      .tabBarMinimizeBehaviorIfAvailable()
      .tabViewStyle(.sidebarAdaptable)
    }
  }
#endif
