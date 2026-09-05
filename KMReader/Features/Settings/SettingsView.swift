//
// SettingsView.swift
//
//

import SwiftUI

struct SettingsView: View {
  @AppStorage("taskQueueStatus") private var taskQueueStatus: TaskQueueSSEDto = TaskQueueSSEDto()
  #if os(iOS) || os(tvOS)
    @AppStorage("keepScreenAwakeWhileReading") private var keepScreenAwakeWhileReading: Bool = false
  #endif

  /// iPhone has no Server tab; the current-server card and single-row
  /// management/account entries live in Settings instead.
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

      Section {
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
        #if os(iOS) || os(tvOS)
          Toggle(isOn: $keepScreenAwakeWhileReading) {
            VStack(alignment: .leading, spacing: 4) {
              Text(String(localized: "Keep Screen Awake While Reading"))
              Text(String(localized: "Prevents the screen from dimming or locking while a reader is open."))
                .font(.caption)
                .foregroundColor(.secondary)
            }
          }
        #endif
      } header: {
        Text(String(localized: "Reader"))
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
        Section {
          NavigationLink(value: NavDestination.settingsManagement) {
            SettingsBadgeRow(
              title: String(localized: "Management"),
              icon: "server.rack",
              color: .indigo,
              badge: taskQueueStatus.count > 0 ? "\(taskQueueStatus.count)" : nil,
              badgeColor: .accentColor
            )
          }
          NavigationLink(value: NavDestination.settingsAccount) {
            SettingsBadgeRow(
              title: ServerSection.account.title,
              icon: ServerSection.account.icon,
              color: ServerSection.account.color
            )
          }
        } header: {
          Text(String(localized: "Server"))
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
      }

      Section(header: Text(String(localized: "Advanced"))) {
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

      Section {
        NavigationLink(value: NavDestination.settingsAbout) {
          SettingsSectionRow(section: .about)
        }
      }
    }
    .formStyle(.grouped)
    .inlineNavigationBarTitle(String(localized: "title.settings"))
  }
}
