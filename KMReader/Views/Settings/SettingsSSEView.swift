//
//  SettingsSSEView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct SettingsSSEView: View {
  @AppStorage("enableSSE") private var enableSSE: Bool = true
  @AppStorage("enableSSENotifications") private var enableSSENotifications: Bool = true
  @AppStorage("enableSSEAutoRefresh") private var enableSSEAutoRefresh: Bool = true
  @AppStorage("isLoggedIn") private var isLoggedIn: Bool = false

  var body: some View {
    Form {
      Section {
        Toggle(isOn: $enableSSE) {
          VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
              Image(systemName: "antenna.radiowaves.left.and.right")
              Text("Real-time Updates")
            }
            Text("Enable Server-Sent Events for real-time updates")
              .font(.caption)
              .foregroundColor(.secondary)
          }
        }
        .onChange(of: enableSSE) { _, newValue in
          // Always disconnect first to ensure clean state
          SSEService.shared.disconnect()
          // Then connect if enabled and logged in
          if newValue && isLoggedIn {
            SSEService.shared.connect()
          }
        }
      } header: {
        Text("Connection")
      } footer: {
        Text(
          "Real-time updates allow the app to automatically refresh when content changes on the server."
        )
      }

      Section {
        Toggle(isOn: $enableSSEAutoRefresh) {
          VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
              Image(systemName: "arrow.clockwise")
              Text("Auto-refresh Dashboard")
            }
            Text("Automatically refresh dashboard when content changes")
              .font(.caption)
              .foregroundColor(.secondary)
          }
        }
        .disabled(!enableSSE)
      } header: {
        Text("Auto-refresh")
      } footer: {
        Text(
          enableSSE
            ? "When disabled, the dashboard will not automatically refresh when SSE events are received. You can still manually refresh."
            : "Enable Real-time Updates above to use this feature."
        )
      }

      Section {
        Toggle(isOn: $enableSSENotifications) {
          VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
              Image(systemName: "bell")
              Text("Show Notifications")
            }
            Text("Show connection status and task completion notifications")
              .font(.caption)
              .foregroundColor(.secondary)
          }
        }
        .disabled(!enableSSE)
      } header: {
        Text("Notifications")
      } footer: {
        Text(
          enableSSE
            ? "When disabled, connection status and task completion messages will not be shown."
            : "Enable Real-time Updates above to use this feature."
        )
      }
    }
    .formStyle(.grouped)
    .inlineNavigationBarTitle("Real-time Updates")
  }
}
