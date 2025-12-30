//
//  MainTabView.swift
//  KMReader
//
//  Created by Komga iOS Client
//

import SwiftUI

@available(iOS 18.0, macOS 15.0, tvOS 18.0, *)
struct MainTabView: View {
  @Environment(AuthViewModel.self) private var authViewModel
  @AppStorage("currentInstanceId") private var currentInstanceId: String = ""
  @AppStorage("isOffline") private var isOffline: Bool = false
  @AppStorage("isAdmin") private var isAdmin: Bool = false

  @State private var selectedTab: TabItem = .home

  private var settingsTabRole: TabRole? {
    #if os(iOS)
      PlatformHelper.isPad ? nil : .search
    #else
      nil
    #endif
  }

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
        Tab(
          TabItem.settings.title, systemImage: TabItem.settings.icon, value: TabItem.settings,
          role: settingsTabRole
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
