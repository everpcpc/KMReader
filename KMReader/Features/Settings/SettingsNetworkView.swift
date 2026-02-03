//
//  SettingsNetworkView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct SettingsNetworkView: View {
  @AppStorage("apiTimeout") private var apiTimeout: Double = 10
  @AppStorage("apiRetryCount") private var apiRetryCount: Int = 0
  @AppStorage("enableBrowseHandoff") private var enableBrowseHandoff: Bool = true
  @AppStorage("enableReaderHandoff") private var enableReaderHandoff: Bool = false

  var body: some View {
    Form {
      Section(header: Text(String(localized: "settings.network.general"))) {
        VStack(alignment: .leading, spacing: 8) {
          HStack {
            Label(String(localized: "settings.network.api_timeout.label"), systemImage: "clock")
            Spacer()
            #if os(tvOS)
              Text("\(Int(apiTimeout))s")
                .foregroundStyle(.secondary)
            #elseif os(macOS)
              TextField("", value: $apiTimeout, format: .number)
                .multilineTextAlignment(.trailing)
                .frame(width: 50)
              Text("s")
                .foregroundStyle(.secondary)
            #else
              TextField("Timeout Seconds", value: $apiTimeout, format: .number)
                .keyboardType(.numbersAndPunctuation)
                .multilineTextAlignment(.trailing)
                .frame(width: 50)
              Text("s")
                .foregroundStyle(.secondary)
            #endif
          }
          Text(String(localized: "settings.network.api_timeout.description"))
            .font(.caption)
            .foregroundStyle(.secondary)
        }

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
}
