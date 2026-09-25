//
// ReaderPreferencesView.swift
//
//

import SwiftUI

/// Settings shared by all readers (DIVINA, EPUB, PDF). Per-reader options
/// stay in the per-reader pages and the in-reader sheets.
struct ReaderPreferencesView: View {
  @AppStorage("progressRecordingThreshold") private var progressRecordingThreshold: Int =
    AppConfig.progressRecordingThreshold
  #if os(iOS)
    @AppStorage("enableReaderLiveActivity") private var enableReaderLiveActivity: Bool = true
  #endif
  #if os(iOS) || os(tvOS)
    @AppStorage("keepScreenAwakeWhileReading") private var keepScreenAwakeWhileReading: Bool = false
  #endif

  var body: some View {
    Form {
      Section(header: Text("Reading Progress")) {
        VStack(alignment: .leading, spacing: 8) {
          Picker("Record Progress After", selection: $progressRecordingThreshold) {
            ForEach([0, 1, 3, 5, 10], id: \.self) { value in
              Text(progressRecordingThresholdLabel(for: value)).tag(value)
            }
          }
          .pickerStyle(.menu)
          Text("Reading progress is recorded only after you turn this many pages from the page you opened at.")
            .font(.caption)
            .foregroundColor(.secondary)
        }
      }

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
    }
    .formStyle(.grouped)
    .inlineNavigationBarTitle(SettingsSection.reading.title)
  }

  private func progressRecordingThresholdLabel(for value: Int) -> String {
    if value == 0 { return String(localized: "Immediately") }
    if value == 1 { return String(localized: "1 page") }
    return String(localized: "\(value) pages")
  }
}
