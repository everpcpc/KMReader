//
//  ContentView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct ContentView: View {
  @Environment(AuthViewModel.self) private var authViewModel

  var body: some View {
    Group {
      if authViewModel.isLoggedIn {
        MainTabView()
      } else {
        LoginView()
      }
    }
    .onAppear {
      if authViewModel.isLoggedIn {
        Task {
          await authViewModel.loadCurrentUser()
        }
      }
    }
  }
}

struct MainTabView: View {
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
  }
}

struct SettingsView: View {
  @Environment(AuthViewModel.self) private var authViewModel

  var body: some View {
    NavigationView {
      Form {
        Section(header: Text("Account")) {
          if let user = authViewModel.user {
            HStack {
              Text("Email")
              Spacer()
              Text(user.email)
                .foregroundColor(.secondary)
            }
          }
        }

        Section {
          Button(role: .destructive) {
            authViewModel.logout()
          } label: {
            HStack {
              Spacer()
              Text("Logout")
              Spacer()
            }
          }
        }
      }
      .navigationTitle("Settings")
      .navigationBarTitleDisplayMode(.inline)
    }
  }
}

#Preview {
  ContentView()
    .environment(AuthViewModel())
}
