//
//  SettingsView_macOS.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

#if os(macOS)
  struct SettingsView_macOS: View {
    @State private var selectedSection: SettingsSection? = .appearance
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
      NavigationSplitView(columnVisibility: $columnVisibility) {
        List(selection: $selectedSection) {
          Section(String(localized: "Reader")) {
            SettingsSectionRow(section: .divinaReader)
            SettingsSectionRow(section: .pdfReader)
          }

          Section(String(localized: "Display")) {
            SettingsSectionRow(section: .appearance)
            SettingsSectionRow(section: .browse)
            SettingsSectionRow(section: .dashboard)
          }

          Section(String(localized: "Behavior")) {
            SettingsSectionRow(section: .sse)
            SettingsSectionRow(section: .spotlight)
            SettingsSectionRow(section: .network)
            SettingsSectionRow(section: .cache)
            SettingsSectionRow(section: .logs)
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
            case .pdfReader:
              PdfPreferencesView()
            case .sse:
              SettingsSSEView()
            case .spotlight:
              SettingsSpotlightView()
            case .network:
              SettingsNetworkView()
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
