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
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
      NavigationSplitView(columnVisibility: $columnVisibility) {
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
            SettingsOfflineTasksRow()
            SettingsSectionRow(section: .offlineBooks)
          }

          Section("Management") {
            SettingsSectionRow(section: .libraries)
            SettingsSectionRow(section: .serverInfo)
              .disabled(!isAdmin)
            SettingsSectionRow(
              section: .tasks,
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
        .toolbar(removing: .sidebarToggle)
        .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 300)
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
            case .logs:
              SettingsLogsView()

            case .offlineTasks:
              SettingsOfflineTasksView()
            case .offlineBooks:
              SettingsOfflineBooksView()

            case .libraries:
              SettingsLibrariesView()
            case .serverInfo:
              SettingsServerInfoView()
            case .tasks:
              SettingsTasksView()

            case .servers:
              SettingsServersView()
            case .apiKeys:
              SettingsApiKeyView()
            case .authenticationActivity:
              AuthenticationActivityView()
            }
          }
          .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
          Text("Select a setting")
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
      }
      .onChange(of: columnVisibility) { _, newValue in
        if newValue != .all {
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            columnVisibility = .all
          }
        }
      }
    }
  }
#endif
