//
//  SettingsView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct SettingsView: View {
  @Environment(AuthViewModel.self) private var authViewModel
  @AppStorage("isAdmin") private var isAdmin: Bool = false
  @AppStorage("serverDisplayName") private var serverDisplayName: String = ""

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
          .disabled(!isAdmin)
          NavigationLink(value: NavDestination.settingsMetrics) {
            Label("Metrics", systemImage: "chart.bar")
          }
          .disabled(!isAdmin)
        }

        Section(header: Text("Account")) {
          NavigationLink(value: NavDestination.settingsServers) {
            HStack {
              Label("Servers", systemImage: "list.bullet.rectangle")
              if !serverDisplayName.isEmpty {
                Spacer()
                Text(serverDisplayName)
                  .lineLimit(1)
                  .foregroundColor(.secondary)
              }
            }
          }
          if let user = authViewModel.user {
            HStack {
              Label("User", systemImage: "person")
              Spacer()
              Text(user.email)
                .lineLimit(1)
                .foregroundColor(.secondary)
            }
            HStack {
              Label("Role", systemImage: "shield")
              Spacer()
              Text(isAdmin ? "Admin" : "User")
                .lineLimit(1)
                .foregroundColor(.secondary)
            }
          }
          NavigationLink(value: NavDestination.settingsAuthenticationActivity) {
            Label("Authentication Activity", systemImage: "clock")
          }
          .disabled(!isAdmin)
        }

        HStack {
          Spacer()
          Text(appVersion).foregroundColor(.secondary)
          Spacer()
        }
      }

      .handleNavigation()
      .inlineNavigationBarTitle("Settings")
    }
  }

  private var appVersion: String {
    let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
    return "v\(version) (build \(build))"
  }
}
