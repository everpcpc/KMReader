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
            SettingsSectionRow(section: .authenticationActivity)
          }

          Section {
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
              Text(Bundle.main.appVersion)
                .foregroundColor(.secondary)
                .font(.caption)
              Spacer()
            }
          }
        }
        .toolbar(removing: .sidebarToggle)
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
    }
  }
#endif
