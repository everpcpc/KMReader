//
//  SettingsView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

#if !os(macOS)
  struct SettingsView: View {
    @Environment(AuthViewModel.self) private var authViewModel
    @AppStorage("isAdmin") private var isAdmin: Bool = false
    @AppStorage("serverDisplayName") private var serverDisplayName: String = ""
    @AppStorage("themeColorHex") private var themeColor: ThemeColor = .orange
    @AppStorage("taskQueueStatus") private var taskQueueStatus: TaskQueueSSEDto = TaskQueueSSEDto()

    var body: some View {
      NavigationStack {
        Form {
          Section {
            NavigationLink(value: NavDestination.settingsAppearance) {
              Label("Appearance", systemImage: "paintbrush")
            }
            NavigationLink(value: NavDestination.settingsDashboard) {
              Label("Dashboard", systemImage: "house")
            }
            NavigationLink(value: NavDestination.settingsCache) {
              Label("Cache", systemImage: "externaldrive")
            }
            NavigationLink(value: NavDestination.settingsReader) {
              Label("Reader", systemImage: "book.pages")
            }
            NavigationLink(value: NavDestination.settingsSSE) {
              Label("Real-time Updates", systemImage: "antenna.radiowaves.left.and.right")
            }
            NavigationLink(value: NavDestination.settingsOfflineTasks) {
              Label("Offline Tasks", systemImage: "square.and.arrow.down.on.square")
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
              HStack {
                Label("Tasks", systemImage: "list.bullet.clipboard")
                Spacer()
                if taskQueueStatus.count > 0 {
                  HStack(spacing: 4) {
                    Circle()
                      .fill(themeColor.color)
                      .frame(width: 8, height: 8)
                    Text("\(taskQueueStatus.count)")
                      .font(.caption)
                      .foregroundColor(themeColor.color)
                      .fontWeight(.semibold)
                  }
                }
              }
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
            NavigationLink(value: NavDestination.settingsApiKey) {
              Label(String(localized: "API Keys"), systemImage: "key")
            }
            NavigationLink(value: NavDestination.settingsAuthenticationActivity) {
              Label(String(localized: "Authentication Activity"), systemImage: "clock")
            }
          }

          SettingsAboutSection()
        }
        .formStyle(.grouped)
        .handleNavigation()
        .inlineNavigationBarTitle(String(localized: "title.settings"))
      }
    }
  }
#endif
