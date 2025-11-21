//
//  SettingsView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct SettingsView: View {
  @Environment(AuthViewModel.self) private var authViewModel

  var body: some View {
    NavigationStack {
      Form {
        Section(header: Text("Management")) {
          NavigationLink(value: NavDestination.settingsLibraries) {
            Label("Libraries", systemImage: "books.vertical")
          }
          NavigationLink(value: NavDestination.settingsServerInfo) {
            Label("Server Info", systemImage: "server.rack")
          }
        }

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

        Section(header: Text("Account")) {
          if let user = authViewModel.user {
            HStack {
              Label("Email", systemImage: "envelope")
              Spacer()
              Text(user.email)
                .foregroundColor(.secondary)
            }
            HStack {
              Label("Roles", systemImage: "person.2")
              Spacer()
              Text(user.roles.joined(separator: ", "))
                .font(.caption)
                .lineLimit(1)
                .foregroundColor(.secondary)
            }
          }
          NavigationLink(value: NavDestination.settingsAuthenticationActivity) {
            Label("Authentication Activity", systemImage: "clock")
          }
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

        Section(header: Text("About")) {
          HStack {
            Label("Version", systemImage: "info.circle")
            Spacer()
            Text(appVersion)
              .foregroundColor(.secondary)
          }
        }
      }
      .handleNavigation()
      .navigationTitle("Settings")
      .navigationBarTitleDisplayMode(.inline)
    }
  }

  private var appVersion: String {
    let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
    return "v\(version) (build \(build))"
  }
}
