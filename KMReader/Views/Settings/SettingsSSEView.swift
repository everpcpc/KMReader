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

  var body: some View {
    List {
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
        .onChange(of: enableSSE) { oldValue, newValue in
          // Always disconnect first to ensure clean state
          SSEService.shared.disconnect()
          // Then connect if enabled and logged in
          if newValue && AppConfig.isLoggedIn {
            SSEService.shared.connect()
          }
        }
      } header: {
        Text("Connection")
      } footer: {
        Text("Real-time updates allow the app to automatically refresh when content changes on the server.")
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
      } header: {
        Text("Notifications")
      } footer: {
        Text("When disabled, connection status and task completion messages will not be shown.")
      }
    }
    .optimizedListStyle()
    .inlineNavigationBarTitle("Real-time Updates")
  }
}
