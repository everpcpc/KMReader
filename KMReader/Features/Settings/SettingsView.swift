//
// SettingsView.swift
//
//

import SwiftUI

struct SettingsView: View {
  let authViewModel: AuthViewModel

  @AppStorage("currentAccount") private var current: Current = .init()
  @AppStorage("taskQueueStatus") private var taskQueueStatus: TaskQueueSSEDto = TaskQueueSSEDto()
  @State private var showingUpdatePassword = false

  /// iPhone has no Server tab; the current-server card and the
  /// management/account entries live at the top of Settings instead.
  /// iPad keeps the sidebar Server page, tvOS keeps its Server tab.
  private var showsServerSections: Bool {
    #if os(iOS)
      return !PlatformHelper.isPad
    #else
      return false
    #endif
  }

  var body: some View {
    Form {
      if showsServerSections {
        Section {
          SettingsServerCardView()
        }
      }

      Section(header: Text(String(localized: "Reader"))) {
        #if os(iOS) || os(tvOS)
          NavigationLink(value: NavDestination.settingsReading) {
            SettingsSectionRow(section: .reading)
          }
        #endif
        NavigationLink(value: NavDestination.settingsDivinaReader) {
          SettingsSectionRow(section: .divinaReader)
        }
        #if os(iOS) || os(macOS)
          NavigationLink(value: NavDestination.settingsPdfReader) {
            SettingsSectionRow(section: .pdfReader)
          }
        #endif
        #if os(iOS)
          NavigationLink(value: NavDestination.settingsEpubTheme) {
            SettingsSectionRow(section: .epubTheme)
          }
          NavigationLink(value: NavDestination.settingsEpubSettings) {
            SettingsSectionRow(section: .epubSettings)
          }
        #endif
      }

      Section(header: Text(String(localized: "Display"))) {
        NavigationLink(value: NavDestination.settingsAppearance) {
          SettingsSectionRow(section: .appearance)
        }
        NavigationLink(value: NavDestination.settingsBrowse) {
          SettingsSectionRow(section: .browse)
        }
        NavigationLink(value: NavDestination.settingsDashboard) {
          SettingsSectionRow(section: .dashboard)
        }
      }

      if showsServerSections {
        Section(header: Text(String(localized: "Server"))) {
          NavigationLink(value: NavDestination.settingsLibraries) {
            Label(ServerSection.libraries.title, systemImage: ServerSection.libraries.icon)
          }
          NavigationLink(value: NavDestination.settingsReadingStats) {
            Label(ServerSection.readingStats.title, systemImage: ServerSection.readingStats.icon)
          }
          if current.isAdmin {
            NavigationLink(value: NavDestination.settingsServerInfo) {
              Label(ServerSection.serverInfo.title, systemImage: ServerSection.serverInfo.icon)
            }
            NavigationLink(value: NavDestination.settingsTasks) {
              HStack {
                Label(ServerSection.tasks.title, systemImage: ServerSection.tasks.icon)
                Spacer()
                if taskQueueStatus.count > 0 {
                  Text("\(taskQueueStatus.count)")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(Color.accentColor)
                }
              }
            }
            NavigationLink(value: NavDestination.settingsHistory) {
              Label(ServerSection.history.title, systemImage: ServerSection.history.icon)
            }
            NavigationLink(value: NavDestination.settingsMedia) {
              Label(ServerSection.media.title, systemImage: ServerSection.media.icon)
            }
          }
        }

        Section(header: Text(ServerSection.account.title)) {
          if !current.userId.isEmpty {
            Button {
              showingUpdatePassword = true
            } label: {
              Label(
                String(localized: "account.details.changePassword"),
                systemImage: "key"
              )
              .foregroundColor(.primary)
            }
          }
          NavigationLink(value: NavDestination.settingsApiKey) {
            Label(ServerSection.apiKeys.title, systemImage: ServerSection.apiKeys.icon)
          }
          NavigationLink(value: NavDestination.settingsAuthenticationActivity) {
            Label(
              ServerSection.authenticationActivity.title,
              systemImage: ServerSection.authenticationActivity.icon
            )
          }
        }
      }

      Section(header: Text(String(localized: "Behavior"))) {
        NavigationLink(value: NavDestination.settingsSSE) {
          SettingsSectionRow(section: .sse)
        }
        NavigationLink(value: NavDestination.settingsSync) {
          SettingsSectionRow(section: .sync)
        }
        #if os(iOS) || os(macOS)
          NavigationLink(value: NavDestination.settingsSpotlight) {
            SettingsSectionRow(section: .spotlight)
          }
        #endif
        #if os(iOS) || os(macOS)
          NavigationLink(value: NavDestination.settingsNetwork) {
            SettingsSectionRow(section: .network)
          }
        #endif
        NavigationLink(value: NavDestination.settingsCache) {
          SettingsSectionRow(section: .cache)
        }

        NavigationLink(value: NavDestination.settingsLogs) {
          SettingsSectionRow(section: .logs)
        }
      }

      SettingsAboutSection()
    }
    .formStyle(.grouped)
    .inlineNavigationBarTitle(String(localized: "title.settings"))
    .sheet(isPresented: $showingUpdatePassword) {
      UpdatePasswordSheet(authViewModel: authViewModel)
        .presentationDetents([.medium])
    }
  }
}
