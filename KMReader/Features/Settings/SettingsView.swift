//
// SettingsView.swift
//
//

import SwiftUI

struct SettingsView: View {
  @AppStorage("keepScreenAwakeWhileReading") private var keepScreenAwakeWhileReading: Bool = false

  var body: some View {
    Form {
      Section(header: Text(String(localized: "Reader"))) {
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
            VStack(alignment: .leading, spacing: 2) {
              Text(String(localized: "Keep Screen Awake While Reading"))
              Text(String(localized: "Prevents the screen from dimming or locking while a reader is open."))
                .font(.caption)
                .foregroundStyle(.secondary)
            }
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
  }
}
