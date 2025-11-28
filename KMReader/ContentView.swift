//
//  ContentView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct ContentView: View {
  @Environment(AuthViewModel.self) private var authViewModel
  @AppStorage("themeColorHex") private var themeColor: ThemeColor = .orange
  @AppStorage("isLoggedIn") private var isLoggedIn: Bool = false
  @State private var errorManager = ErrorManager.shared

  var body: some View {
    ZStack {
      Group {
        if isLoggedIn {
          MainTabView()
        } else {
          LandingView()
        }
      }
      .tint(themeColor.color)
      .task {
        if isLoggedIn {
          await authViewModel.loadCurrentUser()
          await LibraryManager.shared.loadLibraries()
        }
      }
      .onChange(of: isLoggedIn) { _, isLoggedIn in
        SDImageCacheProvider.configureSDWebImage()
        if isLoggedIn {
          Task {
            await authViewModel.loadCurrentUser()
            await LibraryManager.shared.loadLibraries()
          }
        }
      }
      .onChange(of: authViewModel.credentialsVersion) {
        SDImageCacheProvider.configureSDWebImage()
      }
      .onAppear {
        SDImageCacheProvider.configureSDWebImage()
      }

      // Notification overlay
      VStack(alignment: .center) {
        Spacer()
        ForEach($errorManager.notifications, id: \.self) { $notification in
          Text(notification)
            .padding(8)
            .foregroundStyle(.white)
            .background(themeColor.color)
            .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 10)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
      }
      .animation(.default, value: errorManager.notifications)
      .padding(.horizontal, 8)
      .padding(.bottom, 64)
    }
    .alert("Error", isPresented: $errorManager.hasAlert) {
      Button("OK") {
        ErrorManager.shared.vanishError()
      }
      Button("Copy") {
        PlatformHelper.generalPasteboard.string = errorManager.currentError?.description
        ErrorManager.shared.notify(message: "Copied")
      }
    } message: {
      if let error = errorManager.currentError {
        Text(verbatim: error.description)
      } else {
        Text("Unknown Error")
      }
    }
  }
}

struct MainTabView: View {
  @AppStorage("themeColorHex") private var themeColor: ThemeColor = .orange

  var body: some View {
    TabView {
      DashboardView()
        .tabItem {
          Label("Home", systemImage: "house")
        }

      BrowseView()
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
    .tint(themeColor.color)
  }
}
