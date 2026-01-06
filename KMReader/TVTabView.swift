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

        Tab(TabItem.browse.title, systemImage: TabItem.browse.icon, value: TabItem.browse) {
          NavigationStack {
            TabItem.browse.content
              .handleNavigation()
          }
        }

        TabSection(String(localized: "Settings")) {
          Tab(TabItem.settings.title, systemImage: TabItem.settings.icon, value: TabItem.settings) {
            NavigationStack {
              TabItem.settings.content
                .handleNavigation()
            }
          }
        }
      }
    }
  }
#endif
