//
//  SettingsNetworkView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct SettingsNetworkView: View {
  @AppStorage("requestTimeout") private var requestTimeout: Double = 20
  @AppStorage("downloadTimeout") private var downloadTimeout: Double = 60
  @AppStorage("authTimeout") private var authTimeout: Double = 10
  @AppStorage("apiRetryCount") private var apiRetryCount: Int = 0
  @AppStorage("enableBrowseHandoff") private var enableBrowseHandoff: Bool = true
  @AppStorage("enableReaderHandoff") private var enableReaderHandoff: Bool = false

  var body: some View {
    Form {
      Section(header: Text(String(localized: "settings.network.general"))) {
        timeoutRow(
          labelKey: "settings.network.request_timeout.label",
          descriptionKey: "settings.network.request_timeout.description",
          value: $requestTimeout
        )

        timeoutRow(
          labelKey: "settings.network.download_timeout.label",
          descriptionKey: "settings.network.download_timeout.description",
          value: $downloadTimeout
        )

        timeoutRow(
          labelKey: "settings.network.auth_timeout.label",
          descriptionKey: "settings.network.auth_timeout.description",
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

  @ViewBuilder
  private func timeoutRow(
    labelKey: String,
    descriptionKey: String,
    value: Binding<Double>
  ) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Label(String(localized: .init(labelKey)), systemImage: "clock")
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
          TextField("Timeout Seconds", value: value, format: .number)
            .keyboardType(.numbersAndPunctuation)
            .multilineTextAlignment(.trailing)
            .frame(width: 50)
          Text("s")
            .foregroundStyle(.secondary)
        #endif
      }
      Text(String(localized: .init(descriptionKey)))
        .font(.caption)
        .foregroundStyle(.secondary)
    }
  }
}
