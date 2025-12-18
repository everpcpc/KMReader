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

  var body: some View {
    Group {
      if isLoggedIn {
        if #available(iOS 18.0, macOS 15.0, tvOS 18.0, *) {
          MainTabView()
        } else {
          OldTabView()
        }
      } else {
        LandingView()
      }
    }
    .task {
      if isLoggedIn {
        await authViewModel.loadCurrentUser()
        await LibraryManager.shared.loadLibraries()
        // Connect to SSE on app startup if already logged in and enabled
        if enableSSE {
          SSEService.shared.connect()
        }
      }
    }
    .onChange(of: isLoggedIn) { _, isLoggedIn in
      if isLoggedIn {
        Task {
          await authViewModel.loadCurrentUser()
          await LibraryManager.shared.loadLibraries()
          // Connect to SSE when login state changes to logged in and enabled
          if enableSSE {
            SSEService.shared.connect()
          }
        }
      } else {
        // Disconnect SSE when logged out
        SSEService.shared.disconnect()
      }
    }
    .onChange(of: scenePhase) { _, phase in
      if phase == .active && isLoggedIn {
        KomgaInstanceStore.shared.updateLastUsed(for: AppConfig.currentInstanceId)
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
