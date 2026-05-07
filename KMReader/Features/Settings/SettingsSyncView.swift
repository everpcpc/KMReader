//
// SettingsSyncView.swift
//
//

import SwiftUI

struct SettingsSyncView: View {
  @AppStorage("readingHistoryAutoSyncIntervalHours") private var readingHistoryAutoSyncIntervalHours: Int = 24
  #if os(iOS) || os(macOS)
    @AppStorage("enableBrowseHandoff") private var enableBrowseHandoff: Bool = true
    @AppStorage("enableReaderHandoff") private var enableReaderHandoff: Bool = false
  #endif
  #if os(iOS)
    @AppStorage("enableReaderLiveActivity") private var enableReaderLiveActivity: Bool = true
  #endif

  var body: some View {
    Form {
      Section(header: Text(String(localized: "settings.network.read_history_sync"))) {
        VStack(alignment: .leading, spacing: 8) {
          #if os(tvOS)
            HStack {
              Label(
                String(localized: "settings.network.read_history_sync.minimum_interval.label"),
                systemImage: "book.circle"
              )
              Spacer()
              Text(readingHistoryAutoSyncIntervalText)
                .foregroundStyle(.secondary)
            }
          #else
            Stepper(value: $readingHistoryAutoSyncIntervalHours, in: 0...168) {
              HStack {
                Label(
                  String(localized: "settings.network.read_history_sync.minimum_interval.label"),
                  systemImage: "book.circle"
                )
                Spacer()
                Text(readingHistoryAutoSyncIntervalText)
                  .foregroundStyle(.secondary)
              }
            }
          #endif
          Text(String(localized: "settings.network.read_history_sync.minimum_interval.description"))
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }

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
    }
    .formStyle(.grouped)
    .inlineNavigationBarTitle(SettingsSection.sync.title)
  }

  private var readingHistoryAutoSyncIntervalText: String {
    guard readingHistoryAutoSyncIntervalHours > 0 else {
      return String(localized: "settings.sync_data.never")
    }

    let formatter = DateComponentsFormatter()
    formatter.allowedUnits = [.hour]
    formatter.unitsStyle = .full
    formatter.maximumUnitCount = 1
    return formatter.string(from: TimeInterval(readingHistoryAutoSyncIntervalHours * 60 * 60))
      ?? "\(readingHistoryAutoSyncIntervalHours) h"
  }
}
