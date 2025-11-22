//
//  SettingsView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct SettingsView: View {
  @Environment(AuthViewModel.self) private var authViewModel
  @State private var showLogoutAlert = false

  var body: some View {
    NavigationStack {
      List {
        Section {
          NavigationLink(value: NavDestination.settingsAppearance) {
            Label("Appearance", systemImage: "paintbrush")
          }
          NavigationLink(value: NavDestination.settingsCache) {
            Label("Cache", systemImage: "externaldrive")
          }
          NavigationLink(value: NavDestination.settingsReader) {
            Label("Reader", systemImage: "book.pages")
          }
        }

        Section(header: Text("Management")) {
          NavigationLink(value: NavDestination.settingsLibraries) {
            Label("Libraries", systemImage: "books.vertical")
          }
          NavigationLink(value: NavDestination.settingsServerInfo) {
            Label("Server Info", systemImage: "server.rack")
          }
          .disabled(!AppConfig.isAdmin)
          NavigationLink(value: NavDestination.settingsMetrics) {
            Label("Metrics", systemImage: "chart.bar")
          }
          .disabled(!AppConfig.isAdmin)
        }

        Section(header: Text("Account")) {
          if let user = authViewModel.user {
            HStack {
              Label("Email", systemImage: "envelope")
              Spacer()
              Text(user.email)
                .foregroundColor(.secondary)
            }
            HStack {
              Label("Admin", systemImage: "person.2")
              Spacer()
              Text(AppConfig.isAdmin ? "Yes" : "No")
                .foregroundColor(.secondary)
            }
          }
          NavigationLink(value: NavDestination.settingsAuthenticationActivity) {
            Label("Authentication Activity", systemImage: "clock")
          }
          Button(role: .destructive) {
            showLogoutAlert = true
          } label: {
            HStack {
              Spacer()
              Text("Logout")
              Spacer()
            }
          }
        }

        HStack {
          Spacer()
          Text(appVersion).foregroundColor(.secondary)
          Spacer()
        }
      }

      .handleNavigation()
      .navigationTitle("Settings")
      .navigationBarTitleDisplayMode(.inline)
      .alert("Logout", isPresented: $showLogoutAlert) {
        Button("Cancel", role: .cancel) {}
        Button("Logout", role: .destructive) {
          authViewModel.logout()
        }
      } message: {
        Text("Are you sure you want to logout?")
      }
    }
  }

  private var appVersion: String {
    let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
    return "v\(version) (build \(build))"
  }
}
