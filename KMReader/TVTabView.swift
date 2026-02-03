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

        Tab(TabItem.offline.title, systemImage: TabItem.offline.icon, value: TabItem.offline) {
          NavigationStack {
            TabItem.offline.content
              .handleNavigation()
          }
        }

        Tab(TabItem.server.title, systemImage: TabItem.server.icon, value: TabItem.server) {
          NavigationStack {
            TabItem.server.content
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
