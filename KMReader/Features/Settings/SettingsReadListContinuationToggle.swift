//
// SettingsReadListContinuationToggle.swift
//
//

import SwiftUI

/// The opt-in switch for read list continuation on the Dashboard settings page.
/// Turning it on adds the Read Lists in Progress section to the dashboard;
/// turning it off removes it, and the feature stops recording, syncing, and
/// redirecting navigation.
struct SettingsReadListContinuationToggle: View {
  @AppStorage("readListContinuationEnabled") private var readListContinuationEnabled: Bool = false
  @AppStorage("dashboard") private var dashboard: DashboardConfiguration = DashboardConfiguration()

  var body: some View {
    Toggle(isOn: $readListContinuationEnabled) {
      VStack(alignment: .leading, spacing: 4) {
        Text(String(localized: "settings.dashboard.readListContinuation.title"))
        Text(String(localized: "settings.dashboard.readListContinuation.caption"))
          .font(.caption)
          .foregroundColor(.secondary)
      }
    }
    .onChange(of: readListContinuationEnabled) { _, enabled in
      var configuration = dashboard
      if enabled {
        configuration.insertSection(.readListsInProgress)
      } else {
        configuration.removeSection(.readListsInProgress)
      }
      dashboard = configuration
      ReadListReadingService.shared.settingDidChange()
    }
  }
}
