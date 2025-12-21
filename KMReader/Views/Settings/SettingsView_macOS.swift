//
//  SettingsView_macOS.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

#if os(macOS)
  struct SettingsView_macOS: View {
    @Environment(AuthViewModel.self) private var authViewModel
    @AppStorage("isAdmin") private var isAdmin: Bool = false
    @AppStorage("serverDisplayName") private var serverDisplayName: String = ""
    @AppStorage("themeColorHex") private var themeColor: ThemeColor = .orange
    @AppStorage("taskQueueStatus") private var taskQueueStatus: TaskQueueSSEDto = TaskQueueSSEDto()

    @State private var selectedSection: SettingsSection? = .appearance

    var body: some View {
      NavigationSplitView {
        List(selection: $selectedSection) {
          Section("General") {
            SettingsSectionRow(section: .appearance)
            SettingsSectionRow(section: .dashboard)
            SettingsSectionRow(section: .cache)
            SettingsSectionRow(section: .reader)
            SettingsSectionRow(section: .sse)
            SettingsSectionRow(section: .logs)
          }

          Section("Offline") {
            SettingsSectionRow(section: .offlineTasks)
            SettingsSectionRow(section: .offlineBooks)
          }

          Section("Management") {
            SettingsSectionRow(section: .libraries)
            SettingsSectionRow(section: .serverInfo)
              .disabled(!isAdmin)
            SettingsSectionRow(
              section: .metrics,
              badge: taskQueueStatus.count > 0 ? "\(taskQueueStatus.count)" : nil,
              badgeColor: themeColor.color
            )
            .disabled(!isAdmin)
          }

          Section("Account") {
            SettingsSectionRow(
              section: .servers,
              subtitle: serverDisplayName.isEmpty ? nil : serverDisplayName
            )
            if let user = authViewModel.user {
              HStack {
                Label("User", systemImage: "person")
                Spacer()
                Text(user.email)
                  .foregroundColor(.secondary)
              }
              HStack {
                Label("Role", systemImage: "shield")
                Spacer()
                Text(isAdmin ? "Admin" : "User")
                  .foregroundColor(.secondary)
              }
            }
            SettingsSectionRow(section: .apiKeys)
            SettingsSectionRow(section: .authenticationActivity)
          }

          SettingsAboutSection()
        }
        .listStyle(.sidebar)
        .frame(minWidth: 200, minHeight: 400)
        .navigationTitle("Settings")
      } detail: {
        if let selectedSection {
          Group {
            switch selectedSection {
            case .appearance:
              SettingsAppearanceView()
            case .dashboard:
              SettingsDashboardView()
            case .cache:
              SettingsCacheView()
            case .reader:
              SettingsReaderView()
            case .sse:
              SettingsSSEView()
            case .libraries:
              SettingsLibrariesView()
            case .serverInfo:
              SettingsServerInfoView()
            case .metrics:
              SettingsTasksView()
            case .servers:
              SettingsServersView()
            case .apiKeys:
              SettingsApiKeyView()
            case .authenticationActivity:
              AuthenticationActivityView()
            case .offlineTasks:
              SettingsOfflineTasksView()
            case .offlineBooks:
              SettingsOfflineBooksView()
            case .logs:
              SettingsLogsView()
            }
          }
          .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
          Text("Select a setting")
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
      }
    }
  }
#endif
