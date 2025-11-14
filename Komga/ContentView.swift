//
//  ContentView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct ContentView: View {
  @Environment(AuthViewModel.self) private var authViewModel
  @AppStorage("themeColorName") private var themeColorOption: ThemeColorOption = .orange

  var body: some View {
    Group {
      if authViewModel.isLoggedIn {
        MainTabView()
      } else {
        LoginView()
      }
    }
    .tint(themeColorOption.color)
    .onChange(of: authViewModel.isLoggedIn) { _, isLoggedIn in
      if isLoggedIn {
        Task {
          await authViewModel.loadCurrentUser()
          await LibraryManager.shared.loadLibraries()
        }
      }
    }
    .onAppear {
      if authViewModel.isLoggedIn {
        Task {
          await authViewModel.loadCurrentUser()
          await LibraryManager.shared.loadLibraries()
        }
      }
    }
  }
}

struct MainTabView: View {
  @AppStorage("themeColorName") private var themeColorOption: ThemeColorOption = .orange

  var body: some View {
    TabView {
      DashboardView()
        .tabItem {
          Label("Home", systemImage: "house")
        }

      LibraryListView()
        .tabItem {
          Label("Browse", systemImage: "books.vertical")
        }

      HistoryView()
        .tabItem {
          Label("History", systemImage: "clock")
        }

      SettingsView()
        .tabItem {
          Label("Settings", systemImage: "gearshape")
        }
    }
    .tint(themeColorOption.color)
  }
}
