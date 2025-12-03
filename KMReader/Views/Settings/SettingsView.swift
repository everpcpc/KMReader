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
            NavigationLink(value: NavDestination.settingsAuthenticationActivity) {
              Label("Authentication Activity", systemImage: "clock")
            }
          }

          Section(header: Text("About")) {
            Link(destination: URL(string: "https://everpcpc.github.io/KMReader/privacy/")!) {
              Label("Privacy Policy", systemImage: "hand.raised")
            }
            Link(destination: URL(string: "https://kmreader.userjot.com/")!) {
              Label("Feedback", systemImage: "message")
            }
            Link(destination: URL(string: "https://discord.gg/komga-678794935368941569")!) {
              Label("Discuss", systemImage: "bubble.left.and.bubble.right")
            }
            Link(destination: URL(string: "https://github.com/everpcpc/KMReader")!) {
              Label("Source Code", systemImage: "chevron.left.forwardslash.chevron.right")
            }
            HStack {
              Spacer()
              Text(Bundle.main.appVersion).foregroundColor(.secondary)
              Spacer()
            }
          }
        }
        .formStyle(.grouped)
        .handleNavigation()
        .inlineNavigationBarTitle("Settings")
      }
    }
  }
#endif
