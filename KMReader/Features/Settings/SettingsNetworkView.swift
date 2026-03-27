//
// SettingsNetworkView.swift
//
//

import SwiftUI

struct SettingsNetworkView: View {
  @AppStorage("requestTimeout") private var requestTimeout: Double = 15
  @AppStorage("downloadTimeout") private var downloadTimeout: Double = 60
  @AppStorage("authTimeout") private var authTimeout: Double = 5
  @AppStorage("apiRetryCount") private var apiRetryCount: Int = 0
  @AppStorage("readingHistoryAutoSyncIntervalHours") private var readingHistoryAutoSyncIntervalHours: Int = 24
  @AppStorage("enableBrowseHandoff") private var enableBrowseHandoff: Bool = true
  @AppStorage("enableReaderHandoff") private var enableReaderHandoff: Bool = false

  var body: some View {
    Form {
      Section(header: Text(String(localized: "settings.network.general"))) {
        timeoutRow(
          label: "settings.network.request_timeout.label",
          description: "settings.network.request_timeout.description",
          value: $requestTimeout
        )

        timeoutRow(
          label: "settings.network.download_timeout.label",
          description: "settings.network.download_timeout.description",
          value: $downloadTimeout
        )

        timeoutRow(
          label: "settings.network.auth_timeout.label",
          description: "settings.network.auth_timeout.description",
          value: $authTimeout
        )

        VStack(alignment: .leading, spacing: 8) {
          #if os(tvOS)
            HStack {
              Label(
                String(localized: "settings.network.api_retry_count.label"),
                systemImage: "arrow.counterclockwise")
              Spacer()
              Text("\(apiRetryCount)")
                .foregroundStyle(.secondary)
            }
          #else
            Stepper(value: $apiRetryCount, in: 0...5) {
              HStack {
                Label(
                  String(localized: "settings.network.api_retry_count.label"),
                  systemImage: "arrow.counterclockwise")
                Spacer()
                Text("\(apiRetryCount)")
                  .foregroundStyle(.secondary)
              }
            }
          #endif
          Text(String(localized: "settings.network.api_retry_count.description"))
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }

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
    }
    .formStyle(.grouped)
    .inlineNavigationBarTitle(SettingsSection.network.title)
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

  @ViewBuilder
  private func timeoutRow(
    label: LocalizedStringResource,
    description: LocalizedStringResource,
    value: Binding<Double>
  ) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Label {
          Text(label)
        } icon: {
          Image(systemName: "clock")
        }
        Spacer()
        #if os(tvOS)
          Text("\(Int(value.wrappedValue))s")
            .foregroundStyle(.secondary)
        #elseif os(macOS)
          TextField("", value: value, format: .number)
            .multilineTextAlignment(.trailing)
            .frame(width: 50)
          Text("s")
            .foregroundStyle(.secondary)
        #else
          TextField(String(localized: "Timeout Seconds"), value: value, format: .number)
            .keyboardType(.numbersAndPunctuation)
            .multilineTextAlignment(.trailing)
            .frame(width: 50)
          Text("s")
            .foregroundStyle(.secondary)
        #endif
      }
      Text(description)
        .font(.caption)
        .foregroundStyle(.secondary)
    }
  }
}
