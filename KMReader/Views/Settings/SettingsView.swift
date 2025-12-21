//
//  SettingsView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftData
import SwiftUI

#if !os(macOS)
  struct SettingsView: View {
    @Environment(AuthViewModel.self) private var authViewModel
    @AppStorage("isAdmin") private var isAdmin: Bool = false
    @AppStorage("serverDisplayName") private var serverDisplayName: String = ""
    @AppStorage("themeColorHex") private var themeColor: ThemeColor = .orange
    @AppStorage("taskQueueStatus") private var taskQueueStatus: TaskQueueSSEDto = TaskQueueSSEDto()
    @AppStorage("isOffline") private var isOffline: Bool = false
    @AppStorage("currentInstanceId") private var currentInstanceId: String = ""

    @Query private var instances: [KomgaInstance]

    @State private var isCheckingConnection = false

    private var instanceInitializer: InstanceInitializer {
      InstanceInitializer.shared
    }

    private var currentInstance: KomgaInstance? {
      guard let uuid = UUID(uuidString: currentInstanceId) else { return nil }
      return instances.first { $0.id == uuid }
    }

    private var lastSyncTimeText: String {
      guard let instance = currentInstance else {
        return String(localized: "settings.sync_data.never")
      }
      let latestSync = max(instance.seriesLastSyncedAt, instance.booksLastSyncedAt)
      if latestSync == Date(timeIntervalSince1970: 0) {
        return String(localized: "settings.sync_data.never")
      }
      let formatter = RelativeDateTimeFormatter()
      formatter.unitsStyle = .short
      return formatter.localizedString(for: latestSync, relativeTo: Date())
    }

    var body: some View {
      NavigationStack {
        Form {
          // Connection status section
          Section {
            if isOffline {
              Button {
                Task {
                  await tryReconnect()
                }
              } label: {
                HStack {
                  Label(String(localized: "settings.offline"), systemImage: "wifi.slash")
                    .foregroundColor(.orange)
                  Spacer()
                  if isCheckingConnection {
                    ProgressView()
                  } else {
                    Text(String(localized: "settings.offline.tap_to_reconnect"))
                      .font(.caption)
                      .foregroundColor(.secondary)
                  }
                }
              }
              .disabled(isCheckingConnection)
            }

            Button {
              Task {
                await InstanceInitializer.shared.syncData()
              }
            } label: {
              HStack {
                Label(
                  String(localized: "settings.sync_data"),
                  systemImage: "arrow.triangle.2.circlepath")
                Spacer()
                if instanceInitializer.isSyncing {
                  ProgressView()
                } else {
                  Text(lastSyncTimeText)
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
              }
            }
            .disabled(instanceInitializer.isSyncing || isOffline)
          } footer: {
            Text(String(localized: "settings.sync_data.description"))
          }

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

    private func tryReconnect() async {
      isCheckingConnection = true
      let serverReachable = await authViewModel.loadCurrentUser()
      isOffline = !serverReachable
      isCheckingConnection = false

      if serverReachable {
        SSEService.shared.connect()
        ErrorManager.shared.notify(message: String(localized: "settings.connection_restored"))
      }
    }
  }
#endif
