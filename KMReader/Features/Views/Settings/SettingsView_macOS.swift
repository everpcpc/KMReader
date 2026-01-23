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
    @AppStorage("currentAccount") private var current: Current = .init()
    @AppStorage("taskQueueStatus") private var taskQueueStatus: TaskQueueSSEDto = TaskQueueSSEDto()

    @State private var selectedSection: SettingsSection? = .appearance
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
      NavigationSplitView(columnVisibility: $columnVisibility) {
        List(selection: $selectedSection) {
          Section("General") {
            SettingsSectionRow(section: .appearance)
            SettingsSectionRow(section: .browse)
            SettingsSectionRow(section: .dashboard)
            SettingsSectionRow(section: .cache)
            SettingsSectionRow(section: .divinaReader)
            SettingsSectionRow(section: .sse)
            SettingsSectionRow(section: .network)
            SettingsSectionRow(section: .logs)
          }

          Section("Offline") {
            SettingsOfflineTasksRow()
            SettingsSectionRow(section: .offlineBooks)
          }

          Section("Management") {
            SettingsSectionRow(section: .libraries)
            if current.isAdmin {
              SettingsSectionRow(section: .serverInfo)
              SettingsSectionRow(
                section: .tasks,
                badge: taskQueueStatus.count > 0 ? "\(taskQueueStatus.count)" : nil,
                badgeColor: Color.accentColor
              )
              SettingsSectionRow(section: .history)
            }
          }

          Section("Account") {
            SettingsSectionRow(
              section: .servers,
              subtitle: current.serverDisplayName.isEmpty ? nil : current.serverDisplayName
            )
            if let user = authViewModel.user {
              SettingsSectionRow(
                section: .account,
                subtitle: user.email
              )
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
            case .browse:
              SettingsBrowseView()
            case .dashboard:
              SettingsDashboardView()
            case .cache:
              SettingsCacheView()
            case .divinaReader:
              DivinaPreferencesView()
            case .sse:
              SettingsSSEView()
            case .network:
              SettingsNetworkView()
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
            case .history:
              SettingsHistoryView()

            case .servers:
              ServersView()
            case .account:
              AccountDetailsView()
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
