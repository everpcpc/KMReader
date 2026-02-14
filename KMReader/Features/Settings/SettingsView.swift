//
//  SettingsView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct SettingsView: View {
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
          NavigationLink(value: NavDestination.settingsEpubReader) {
            SettingsSectionRow(section: .epubReader)
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
        #if !os(tvOS)
          NavigationLink(value: NavDestination.settingsSpotlight) {
            SettingsSectionRow(section: .spotlight)
          }
        #endif
        #if !os(tvOS)
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
