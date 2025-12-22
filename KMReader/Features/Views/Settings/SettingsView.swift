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
          SettingsSyncSection()

          Section {
            NavigationLink(value: NavDestination.settingsAppearance) {
              SettingsSectionRow(section: .appearance)
            }
            NavigationLink(value: NavDestination.settingsDashboard) {
              SettingsSectionRow(section: .dashboard)
            }
            NavigationLink(value: NavDestination.settingsCache) {
              SettingsSectionRow(section: .cache)
            }
            NavigationLink(value: NavDestination.settingsReader) {
              SettingsSectionRow(section: .reader)
            }
            NavigationLink(value: NavDestination.settingsSSE) {
              SettingsSectionRow(section: .sse)
            }
            NavigationLink(value: NavDestination.settingsLogs) {
              SettingsSectionRow(section: .logs)
            }
          }

          Section(header: Text(String(localized: "Offline"))) {
            NavigationLink(value: NavDestination.settingsOfflineTasks) {
              SettingsSectionRow(section: .offlineTasks)
            }
            NavigationLink(value: NavDestination.settingsOfflineBooks) {
              SettingsSectionRow(section: .offlineBooks)
            }
          }

          Section(header: Text(String(localized: "Management"))) {
            NavigationLink(value: NavDestination.settingsLibraries) {
              SettingsSectionRow(section: .libraries)
            }
            NavigationLink(value: NavDestination.settingsServerInfo) {
              SettingsSectionRow(section: .serverInfo)
            }
            .disabled(!isAdmin)
            NavigationLink(value: NavDestination.settingsMetrics) {
              SettingsSectionRow(
                section: .metrics,
                badge: taskQueueStatus.count > 0 ? "\(taskQueueStatus.count)" : nil,
                badgeColor: themeColor.color
              )
            }
            .disabled(!isAdmin)
          }

          Section(header: Text(String(localized: "Account"))) {
            NavigationLink(value: NavDestination.settingsServers) {
              SettingsSectionRow(
                section: .servers,
                subtitle: serverDisplayName.isEmpty ? nil : serverDisplayName
              )
            }
            if let user = authViewModel.user {
              HStack {
                Label(String(localized: "User"), systemImage: "person")
                Spacer()
                Text(user.email)
                  .lineLimit(1)
                  .foregroundColor(.secondary)
              }
              HStack {
                Label(String(localized: "Role"), systemImage: "shield")
                Spacer()
                Text(isAdmin ? String(localized: "Admin") : String(localized: "User"))
                  .lineLimit(1)
                  .foregroundColor(.secondary)
              }
            }
            NavigationLink(value: NavDestination.settingsApiKey) {
              SettingsSectionRow(section: .apiKeys)
            }
            NavigationLink(value: NavDestination.settingsAuthenticationActivity) {
              SettingsSectionRow(section: .authenticationActivity)
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
