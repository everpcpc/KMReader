//
//  SettingsView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftData
import SwiftUI

struct SettingsView: View {
  @Environment(AuthViewModel.self) private var authViewModel
  @AppStorage("isAdmin") private var isAdmin: Bool = false
  @AppStorage("serverDisplayName") private var serverDisplayName: String = ""
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
          NavigationLink(value: NavDestination.settingsNetwork) {
            SettingsSectionRow(section: .network)
          }
        }

        Section(header: Text(String(localized: "Offline"))) {
          NavigationLink(value: NavDestination.settingsOfflineTasks) {
            SettingsOfflineTasksRow()
          }
          NavigationLink(value: NavDestination.settingsOfflineBooks) {
            SettingsSectionRow(section: .offlineBooks)
          }
        }

        Section(header: Text(String(localized: "Management"))) {
          NavigationLink(value: NavDestination.settingsLibraries) {
            SettingsSectionRow(section: .libraries)
          }
          if isAdmin {
            NavigationLink(value: NavDestination.settingsServerInfo) {
              SettingsSectionRow(section: .serverInfo)
            }
            NavigationLink(value: NavDestination.settingsTasks) {
              SettingsSectionRow(
                section: .tasks,
                badge: taskQueueStatus.count > 0 ? "\(taskQueueStatus.count)" : nil,
                badgeColor: Color.accentColor
              )
            }
          }
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
