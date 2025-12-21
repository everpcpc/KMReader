//
//  ContentView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct ContentView: View {
  @Environment(AuthViewModel.self) private var authViewModel
  @Environment(\.scenePhase) private var scenePhase

  @AppStorage("themeColorHex") private var themeColor: ThemeColor = .orange
  @AppStorage("isLoggedIn") private var isLoggedIn: Bool = false
  @AppStorage("enableSSE") private var enableSSE: Bool = true
  @AppStorage("isOffline") private var isOffline: Bool = false

  private var instanceInitializer: InstanceInitializer {
    InstanceInitializer.shared
  }

  private var isReady: Bool {
    (authViewModel.user != nil || isOffline) && !instanceInitializer.isSyncing
  }

  var body: some View {
    Group {
      if isLoggedIn {
        Group {
          if isReady {
            if #available(iOS 18.0, macOS 15.0, tvOS 18.0, *) {
              MainTabView()
            } else {
              OldTabView()
            }
          } else {
            SplashView(initializer: instanceInitializer)
          }
        }
        .task {
          let serverReachable = await authViewModel.loadCurrentUser()
          isOffline = !serverReachable
          if enableSSE && serverReachable {
            SSEService.shared.connect()
          }
        }
        .onChange(of: scenePhase) { _, phase in
          if phase == .active {
            Task {
              await DatabaseOperator.shared.updateInstanceLastUsed(
                instanceId: AppConfig.currentInstanceId)
            }
          }
        }
      } else {
        LandingView()
          .onAppear {
            SSEService.shared.disconnect()
          }
      }
    }
  }
}

@available(iOS 18.0, macOS 15.0, tvOS 18.0, *)
struct MainTabView: View {
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
        TabItem.home.content
      }

      Tab(TabItem.browse.title, systemImage: TabItem.browse.icon, value: TabItem.browse) {
        TabItem.browse.content
      }

      #if !os(macOS)
        Tab(
          TabItem.settings.title, systemImage: TabItem.settings.icon, value: TabItem.settings,
          role: settingsTabRole
        ) {
          TabItem.settings.content
        }
      #endif

    }.tabBarMinimizeBehaviorIfAvailable()
  }
}

struct OldTabView: View {
  @State private var selectedTab: TabItem = .home

  var body: some View {
    TabView(selection: $selectedTab) {
      TabItem.home.content
        .tabItem { TabItem.home.label }

      TabItem.browse.content
        .tabItem { TabItem.browse.label }

      #if !os(macOS)
        TabItem.settings.content
          .tabItem { TabItem.settings.label }
      #endif

    }
  }
}
