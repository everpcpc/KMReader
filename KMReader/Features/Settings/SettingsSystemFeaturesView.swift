//
// SettingsSystemFeaturesView.swift
//
//

import SwiftUI

struct SettingsSystemFeaturesView: View {
  #if os(iOS) || os(macOS)
    @AppStorage("enableBrowseHandoff") private var enableBrowseHandoff: Bool = true
    @AppStorage("enableReaderHandoff") private var enableReaderHandoff: Bool = false
  #endif
  #if os(iOS)
    @AppStorage("enableReaderLiveActivity") private var enableReaderLiveActivity: Bool = true
  #endif
  #if os(iOS) || os(tvOS)
    @AppStorage("keepScreenAwakeWhileReading") private var keepScreenAwakeWhileReading: Bool = false
  #endif

  var body: some View {
    Form {
      #if os(iOS) || os(macOS)
        Section(header: Text(String(localized: "settings.network.handoff"))) {
          Toggle(isOn: $enableBrowseHandoff) {
            VStack(alignment: .leading, spacing: 4) {
              Text(String(localized: "settings.network.handoff.browse.title"))
              Text(String(localized: "settings.network.handoff.browse.caption"))
                .font(.caption)
                .foregroundStyle(.secondary)
            }
          }

          Toggle(isOn: $enableReaderHandoff) {
            VStack(alignment: .leading, spacing: 4) {
              Text(String(localized: "settings.network.handoff.reader.title"))
              Text(String(localized: "settings.network.handoff.reader.caption"))
                .font(.caption)
                .foregroundStyle(.secondary)
            }
          }
        }
      #endif

      #if os(iOS)
        Section(header: Text("Live Activities")) {
          Toggle(isOn: $enableReaderLiveActivity) {
            VStack(alignment: .leading, spacing: 4) {
              Text("Reader Live Activity")
              Text("Show reader progress on the Lock Screen and in Dynamic Island.")
                .font(.caption)
                .foregroundStyle(.secondary)
            }
          }
        }
      #endif

      #if os(iOS) || os(tvOS)
        Section(header: Text(String(localized: "Screen"))) {
          Toggle(isOn: $keepScreenAwakeWhileReading) {
            VStack(alignment: .leading, spacing: 4) {
              Text(String(localized: "Keep Screen Awake While Reading"))
              Text(String(localized: "Prevents the screen from dimming or locking while a reader is open."))
                .font(.caption)
                .foregroundStyle(.secondary)
            }
          }
        }
      #endif
    }
    .formStyle(.grouped)
    .inlineNavigationBarTitle(SettingsSection.systemFeatures.title)
  }
}
